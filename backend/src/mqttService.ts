import mqtt, { MqttClient } from "mqtt";
import { Pool } from "pg";
import { Logger } from "pino";
import { z } from "zod";
import { config } from "./config";
import { createDeviceForUser } from "./db";

const telemetrySchema = z.object({
  deviceId: z.string().regex(/^ESP32_\d{3}$/),
  airTemperature: z.number(),
  airHumidity: z.number().min(0).max(100),
  soilTemperature: z.number(),
  soilMoisture: z.number().min(0).max(100),
  lightLevel: z.number(),
});

const statusSchema = z.object({
  status: z.string().min(1),
});

type TopicKind = "telemetry" | "status";

const DEVICE_ID_REGEX = /^ESP32_\d{3}$/;

const parseTopic = (topic: string): { deviceId: string; kind: TopicKind } | null => {
  const parts = topic.split("/");
  if (parts.length !== 3 || parts[0] !== "greenhouse") {
    return null;
  }
  const [_, deviceId, kind] = parts;
  if (!DEVICE_ID_REGEX.test(deviceId)) {
    return null;
  }
  if (kind !== "telemetry" && kind !== "status") {
    return null;
  }
  return { deviceId, kind };
};

const parseStatusPayload = (payload: string) => {
  try {
    const asJson = JSON.parse(payload);
    return statusSchema.parse(asJson);
  } catch {
    return statusSchema.parse({ status: payload.trim() });
  }
};

const handleTelemetry = async (pool: Pool, logger: Logger, deviceId: string, payload: Buffer) => {
  let telemetry;
  try {
    const parsed = JSON.parse(payload.toString());
    telemetry = telemetrySchema.parse(parsed);
    if (telemetry.deviceId !== deviceId) return;
  } catch (err) {
    logger.warn({ err, deviceId }, "Telemetry payload rejected");
    return;
  }

  const recordedAt = new Date();

  try {
    try {
      await createDeviceForUser(deviceId, 1);
    } catch {}

    await pool.query(
      `
      INSERT INTO telemetry (
        device_id,
        air_temperature,
        air_humidity,
        soil_temperature,
        soil_moisture,
        light_level,
        recorded_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7);
      `,
      [
        deviceId,
        telemetry.airTemperature,
        telemetry.airHumidity,
        telemetry.soilTemperature,
        telemetry.soilMoisture,
        telemetry.lightLevel,
        recordedAt,
      ],
    );
    logger.debug({ deviceId, recordedAt }, "Telemetry stored");
  } catch (err) {
    logger.error({ err, deviceId }, "Failed to store telemetry");
  }
};

const handleStatus = async (pool: Pool, logger: Logger, deviceId: string, payload: Buffer) => {
  const raw = payload.toString();
  let status: string;

  try {
    status = parseStatusPayload(raw).status;
  } catch (err) {
    logger.warn({ err, deviceId }, "Status payload rejected");
    return;
  }

  const reportedAt = new Date();
  try {
    try {
      await createDeviceForUser(deviceId, 1);
    } catch {}

    await pool.query(
      `
      INSERT INTO device_status (device_id, status, reported_at)
      VALUES ($1, $2, $3)
      ON CONFLICT (device_id) DO UPDATE
      SET status = EXCLUDED.status, reported_at = EXCLUDED.reported_at;
      `,
      [deviceId, status, reportedAt],
    );
    logger.debug({ deviceId, status }, "Status updated");
  } catch (err) {
    logger.error({ err, deviceId }, "Failed to store status");
  }
};

export const startMqttIngestion = (pool: Pool, logger: Logger): MqttClient => {
  const client = mqtt.connect(config.mqtt.url, {
    clientId: config.mqtt.clientId,
    username: config.mqtt.username || undefined,
    password: config.mqtt.password || undefined,
    reconnectPeriod: 3_000,
    keepalive: 60,
    clean: true,
  });

  client.on("connect", () => {
    logger.info({ url: config.mqtt.url }, "Connected to MQTT broker");
    client.subscribe(["greenhouse/+/telemetry", "greenhouse/+/status"], (err) => {
      if (err) {
        logger.error({ err }, "Failed to subscribe to MQTT topics");
      } else {
        logger.info("Subscribed to MQTT telemetry and status topics");
      }
    });
  });

  client.on("reconnect", () => logger.warn("Reconnecting to MQTT broker..."));
  client.on("error", (err) => logger.error({ err }, "MQTT error"));
  client.on("offline", () => logger.warn("MQTT client offline"));

  client.on("message", async (topic, payload) => {
    const parsed = parseTopic(topic);
    if (!parsed) {
      logger.warn({ topic }, "Ignoring unexpected MQTT topic");
      return;
    }

    if (parsed.kind === "telemetry") {
      await handleTelemetry(pool, logger, parsed.deviceId, payload);
      return;
    }

    await handleStatus(pool, logger, parsed.deviceId, payload);
  });

  return client;
};