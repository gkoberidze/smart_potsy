import { Pool } from "pg";

// Alert rules for a device
export interface AlertRules {
  airTemperatureMax?: number;
  airTemperatureMin?: number;
  airHumidityMax?: number;
  airHumidityMin?: number;
  soilTemperatureMax?: number;
  soilTemperatureMin?: number;
  soilMoistureMax?: number;
  soilMoistureMin?: number;
  lightLevelMin?: number;
}

// Check if telemetry triggers any alerts
export const checkAlerts = (
  deviceId: string,
  telemetry: any,
  rules: AlertRules
): string[] => {
  const alerts: string[] = [];

  if (
    rules.airTemperatureMax &&
    telemetry.air_temperature > rules.airTemperatureMax
  ) {
    alerts.push(
      `🌡️ ჰაერის ტემპერატურა მაღალია: ${telemetry.air_temperature}°C`
    );
  }

  if (
    rules.airTemperatureMin &&
    telemetry.air_temperature < rules.airTemperatureMin
  ) {
    alerts.push(
      `❄️ ჰაერის ტემპერატურა დაბლაა: ${telemetry.air_temperature}°C`
    );
  }

  if (
    rules.airHumidityMax &&
    telemetry.air_humidity > rules.airHumidityMax
  ) {
    alerts.push(
      `💦 ჰაერის ტენიანობა მაღალია: ${telemetry.air_humidity}%`
    );
  }

  if (
    rules.airHumidityMin &&
    telemetry.air_humidity < rules.airHumidityMin
  ) {
    alerts.push(
      `🌵 ჰაერის ტენიანობა დაბლაა: ${telemetry.air_humidity}%`
    );
  }

  if (
    rules.soilMoistureMin &&
    telemetry.soil_moisture < rules.soilMoistureMin
  ) {
    alerts.push(
      `💧 ნიადაგი უნდა მოსარწყავი იყოს: ${telemetry.soil_moisture}%`
    );
  }

  if (
    rules.soilMoistureMax &&
    telemetry.soil_moisture > rules.soilMoistureMax
  ) {
    alerts.push(
      `🌊 ნიადაგი ძალიან ტენიანია: ${telemetry.soil_moisture}%`
    );
  }

  if (
    rules.soilTemperatureMax &&
    telemetry.soil_temperature > rules.soilTemperatureMax
  ) {
    alerts.push(
      `🔥 ნიადაგის ტემპერატურა მაღალია: ${telemetry.soil_temperature}°C`
    );
  }

  if (
    rules.soilTemperatureMin &&
    telemetry.soil_temperature < rules.soilTemperatureMin
  ) {
    alerts.push(
      `❄️ ნიადაგის ტემპერატურა დაბლაა: ${telemetry.soil_temperature}°C`
    );
  }

  if (rules.lightLevelMin && telemetry.light_level < rules.lightLevelMin) {
    alerts.push(`☀️ სინათლე არ არის საკმარი: ${telemetry.light_level} lux`);
  }

  return alerts;
};

// Send push notification to user
export const sendPushNotification = async (
  pool: Pool,
  userId: number,
  title: string,
  body: string,
  data?: Record<string, string>
) => {
  try {
    // Get user's FCM token
    const userResult = await pool.query(
      "SELECT fcm_token FROM users WHERE id = $1",
      [userId]
    );

    if (userResult.rows.length === 0 || !userResult.rows[0].fcm_token) {
      console.log(`No FCM token for user ${userId}`);
      return false;
    }

    const fcmToken = userResult.rows[0].fcm_token;

    // Send notification via Firebase Cloud Messaging
    // TODO: Implement Firebase Admin SDK integration
    console.log(`📬 Sending notification to ${fcmToken}: ${title} - ${body}`);

    // Save notification to database
    await pool.query(
      `INSERT INTO notifications (user_id, title, body, data, is_read) 
       VALUES ($1, $2, $3, $4, FALSE)`,
      [userId, title, body, JSON.stringify(data || {})]
    );

    return true;
  } catch (error) {
    console.error("Error sending push notification:", error);
    return false;
  }
};

// Get default alert rules for new device
export const getDefaultAlertRules = (): AlertRules => ({
  airTemperatureMax: 35,
  airTemperatureMin: 15,
  airHumidityMax: 90,
  airHumidityMin: 30,
  soilMoistureMin: 40,
  soilMoistureMax: 90,
  lightLevelMin: 200,
});
