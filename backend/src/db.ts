import { Pool } from "pg";
import { config } from "./config";
import { logger } from "./logger";
import { User } from "./types";

export const pool = new Pool({
  connectionString: config.databaseUrl,
  max: 20,
  idleTimeoutMillis: 30_000,
  ssl: false,
});

pool.on("error", (err: Error) => {
  logger.error({ err }, "Unexpected Postgres error");
});

export const closePool = () => pool.end();

export const getUserByEmail = async (email: string): Promise<User | null> => {
  const result = await pool.query(
    "SELECT id, email, password_hash, oauth_provider, oauth_id, reset_token, reset_token_expires, created_at FROM users WHERE email = $1",
    [email]
  );
  return result.rows[0] || null;
};

export const getUserByResetToken = async (token: string): Promise<User | null> => {
  const result = await pool.query(
    "SELECT id, email, password_hash, reset_token, reset_token_expires FROM users WHERE reset_token = $1 AND reset_token_expires > NOW()",
    [token]
  );
  return result.rows[0] || null;
};

export const createUser = async (
  email: string,
  passwordHash: string
): Promise<User> => {
  const result = await pool.query(
    "INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id, email, password_hash, created_at",
    [email, passwordHash]
  );
  return result.rows[0];
};

export const createOAuthUser = async (
  email: string,
  provider: string,
  providerId: string
): Promise<User> => {
  const result = await pool.query(
    "INSERT INTO users (email, oauth_provider, oauth_id) VALUES ($1, $2, $3) RETURNING id, email, created_at",
    [email, provider, providerId]
  );
  return result.rows[0];
};

export const updateUserOAuth = async (
  email: string,
  provider: string,
  providerId: string
): Promise<void> => {
  await pool.query(
    "UPDATE users SET oauth_provider = $1, oauth_id = $2 WHERE email = $3",
    [provider, providerId, email]
  );
};

export const setResetToken = async (
  userId: number,
  token: string,
  expiresAt: Date
): Promise<void> => {
  await pool.query(
    "UPDATE users SET reset_token = $1, reset_token_expires = $2 WHERE id = $3",
    [token, expiresAt, userId]
  );
};

export const updatePassword = async (
  userId: number,
  passwordHash: string
): Promise<void> => {
  await pool.query(
    "UPDATE users SET password_hash = $1, reset_token = NULL, reset_token_expires = NULL WHERE id = $2",
    [passwordHash, userId]
  );
};

export const createDeviceForUser = async (
  deviceId: string,
  userId: number
): Promise<void> => {
  await pool.query(
    "INSERT INTO devices (device_id, user_id) VALUES ($1, $2) ON CONFLICT (device_id) DO NOTHING",
    [deviceId, userId]
  );
};

export const getUserDevices = async (userId: number): Promise<string[]> => {
  const result = await pool.query(
    "SELECT device_id FROM devices WHERE user_id = $1",
    [userId]
  );
  return result.rows.map((row) => row.device_id);
};

export const verifyDeviceOwnership = async (
  deviceId: string,
  userId: number
): Promise<boolean> => {
  const result = await pool.query(
    "SELECT 1 FROM devices WHERE device_id = $1 AND user_id = $2",
    [deviceId, userId]
  );
  return result.rows.length > 0;
};

