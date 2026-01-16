import dotenv from "dotenv";
import path from "path";

// Load env from the project root from inside dist
dotenv.config({ path: path.resolve(__dirname, '../.env') });

const readEnv = (key: string, fallback?: string): string => {
  const value = process.env[key] ?? fallback;
  if (value === undefined) {
    throw new Error(`Missing required env var: ${key}`);
  }
  return value;
};

export const config = {
  env: process.env.NODE_ENV || "development",
  port: parseInt(process.env.PORT || "3000", 10),
  databaseUrl: readEnv("DATABASE_URL"),
  databaseSsl:
    process.env.DATABASE_SSL === "true" ||
    process.env.NODE_ENV === "production",
  frontendUrl: process.env.FRONTEND_URL || "http://localhost:5173",
  mqtt: {
    url: readEnv("MQTT_URL", "mqtt://localhost:1883"),
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD,
    clientId: `greenhouse-backend-${Math.random()
      .toString(16)
      .slice(2, 8)}`,
  },
  jwt: {
    secret: readEnv("JWT_SECRET"),
    expiresIn: process.env.JWT_EXPIRES_IN || "24h",
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || "7d",
  },
  bcrypt: {
    rounds: parseInt(process.env.BCRYPT_ROUNDS || "12", 10),
  },
  logLevel: process.env.LOG_LEVEL || "info",
};
