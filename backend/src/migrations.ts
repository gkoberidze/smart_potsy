import { Pool } from "pg";
import { Logger } from "pino";

export const runMigrations = async (pool: Pool, logger: Logger) => {
  const statements = [
    `
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      email VARCHAR(255) UNIQUE NOT NULL,
      password_hash VARCHAR(255),
      oauth_provider VARCHAR(50),
      oauth_id VARCHAR(255),
      reset_token VARCHAR(255),
      reset_token_expires TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    `,
    `
    CREATE INDEX IF NOT EXISTS users_email_idx ON users (email);
    `,
    `
    CREATE INDEX IF NOT EXISTS users_reset_token_idx ON users (reset_token);
    `,
    `
    INSERT INTO users (id, email, password_hash)
    VALUES (1, 'system@greenhouse.local', 'SYSTEM_USER_NO_LOGIN')
    ON CONFLICT (id) DO NOTHING;
    `,
    `
    CREATE TABLE IF NOT EXISTS devices (
      device_id TEXT PRIMARY KEY,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    `,
    `
    CREATE INDEX IF NOT EXISTS devices_user_id_idx ON devices (user_id);
    `,
    `
    CREATE TABLE IF NOT EXISTS telemetry (
      id BIGSERIAL PRIMARY KEY,
      device_id TEXT NOT NULL REFERENCES devices(device_id) ON DELETE CASCADE,
      air_temperature DOUBLE PRECISION,
      air_humidity DOUBLE PRECISION CHECK (air_humidity BETWEEN 0 AND 100),
      soil_temperature DOUBLE PRECISION,
      soil_moisture DOUBLE PRECISION CHECK (soil_moisture BETWEEN 0 AND 100),
      light_level DOUBLE PRECISION,
      recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    `,
    `
    CREATE INDEX IF NOT EXISTS telemetry_device_time_idx
      ON telemetry (device_id, recorded_at DESC);
    `,
    `
    CREATE TABLE IF NOT EXISTS device_status (
      device_id TEXT PRIMARY KEY REFERENCES devices(device_id) ON DELETE CASCADE,
      status TEXT NOT NULL,
      reported_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    `,
    `
    CREATE INDEX IF NOT EXISTS device_status_time_idx
      ON device_status (reported_at DESC);
    `,
    // Add columns if they don't exist (for existing databases)
    `
    DO $$ BEGIN
      ALTER TABLE users ADD COLUMN IF NOT EXISTS oauth_provider VARCHAR(50);
      ALTER TABLE users ADD COLUMN IF NOT EXISTS oauth_id VARCHAR(255);
      ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_token VARCHAR(255);
      ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_token_expires TIMESTAMPTZ;
      ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;
    EXCEPTION WHEN OTHERS THEN NULL;
    END $$;
    `,
  ];

  for (const statement of statements) {
    await pool.query(statement);
  }

  logger.info("Database migrations applied");
};
