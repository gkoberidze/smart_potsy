import cron from "node-cron";
import { Pool } from "pg";
import { Logger } from "pino";
import { anchorTelemetry, TelemetryWindow } from "../services/SolanaService";

// ─── Query ───────────────────────────────────────────────────────────────────
//
// Aggregates the last hour of telemetry per device.
// Uses exact column names from your telemetry table in migrations.ts:
//   air_temperature, air_humidity, soil_temperature, soil_moisture, light_level
//
const HOURLY_AVERAGES_QUERY = `
  SELECT
    device_id,
    NOW() - INTERVAL '1 hour'               AS window_start,
    NOW()                                    AS window_end,
    COUNT(*)::integer                        AS row_count,
    ROUND(AVG(air_temperature)::numeric, 2)  AS avg_air_temperature,
    ROUND(AVG(air_humidity)::numeric, 2)     AS avg_air_humidity,
    ROUND(AVG(soil_temperature)::numeric, 2) AS avg_soil_temperature,
    ROUND(AVG(soil_moisture)::numeric, 2)    AS avg_soil_moisture,
    ROUND(AVG(light_level)::numeric, 2)      AS avg_light_level
  FROM telemetry
  WHERE recorded_at > NOW() - INTERVAL '1 hour'
  GROUP BY device_id
  HAVING COUNT(*) > 0;
`;

// ─── Store anchor result ──────────────────────────────────────────────────────
//
// Saves the Solana transaction signature and hash back into PostgreSQL
// so you can reference it from the Flutter app or a future audit endpoint.
//
const INSERT_ANCHOR_QUERY = `
  INSERT INTO blockchain_anchors (
    device_id,
    window_start,
    window_end,
    row_count,
    telemetry_hash,
    tx_signature,
    explorer_url,
    anchored_at
  ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8);
`;

// ─── Main job logic ───────────────────────────────────────────────────────────

const runAnchorJob = async (pool: Pool, logger: Logger): Promise<void> => {
  logger.info("Blockchain anchor job started");

  let deviceRows: any[];
  try {
    const result = await pool.query(HOURLY_AVERAGES_QUERY);
    deviceRows = result.rows;
  } catch (err) {
    // DB failure is logged but must not crash the main server
    logger.error({ err }, "Anchor job: failed to query telemetry averages");
    return;
  }

  if (deviceRows.length === 0) {
    logger.info("Anchor job: no telemetry in the last hour, skipping");
    return;
  }

  logger.info({ deviceCount: deviceRows.length }, "Anchor job: processing devices");

  for (const row of deviceRows) {
    // Map Postgres snake_case → TelemetryWindow camelCase
    const window: TelemetryWindow = {
      deviceId:          row.device_id,
      windowStart:       new Date(row.window_start).toISOString(),
      windowEnd:         new Date(row.window_end).toISOString(),
      rowCount:          row.row_count,
      avgAirTemperature: row.avg_air_temperature  !== null ? Number(row.avg_air_temperature)  : null,
      avgAirHumidity:    row.avg_air_humidity     !== null ? Number(row.avg_air_humidity)     : null,
      avgSoilTemperature:row.avg_soil_temperature !== null ? Number(row.avg_soil_temperature) : null,
      avgSoilMoisture:   row.avg_soil_moisture    !== null ? Number(row.avg_soil_moisture)    : null,
      avgLightLevel:     row.avg_light_level      !== null ? Number(row.avg_light_level)      : null,
    };

    try {
      const result = await anchorTelemetry(window, logger);

      // Persist the anchor receipt into PostgreSQL
      await pool.query(INSERT_ANCHOR_QUERY, [
        window.deviceId,
        window.windowStart,
        window.windowEnd,
        window.rowCount,
        result.hash,
        result.signature,
        result.explorerUrl,
        result.anchoredAt,
      ]);

      logger.info(
        { deviceId: window.deviceId, signature: result.signature },
        "Anchor job: device anchored and saved"
      );
    } catch (err) {
      // Per-device failure is isolated — other devices still get anchored
      logger.error({ err, deviceId: row.device_id }, "Anchor job: failed for device");
    }
  }

  logger.info("Blockchain anchor job finished");
};

// ─── Registration ─────────────────────────────────────────────────────────────
//
// Call startAnchorCron(pool, logger) once from index.ts.
// The cron runs at the top of every hour: 00:00, 01:00, 02:00, ...
//
// To test immediately on startup (e.g. during hackathon demo),
// set SOLANA_RUN_ON_STARTUP=true in backend/.env
//

export const startAnchorCron = (pool: Pool, logger: Logger): void => {
  // Schedule: minute=0, every hour, every day
  cron.schedule("0 * * * *", () => {
    runAnchorJob(pool, logger).catch((err) => {
      logger.error({ err }, "Anchor job: unexpected top-level error");
    });
  });

  logger.info("Blockchain anchor cron registered — runs at the top of every hour");

  // Optional: run once immediately so you can see it working right away
  if (process.env.SOLANA_RUN_ON_STARTUP === "true") {
    logger.info("SOLANA_RUN_ON_STARTUP=true — running anchor job now");
    runAnchorJob(pool, logger).catch((err) => {
      logger.error({ err }, "Anchor job: startup run failed");
    });
  }
};