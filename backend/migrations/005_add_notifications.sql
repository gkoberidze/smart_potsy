-- Notifications table
CREATE TABLE IF NOT EXISTS notifications (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  data JSONB,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at);

-- Add fcm_token and alert_rules columns to existing tables
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(255);

ALTER TABLE devices 
ADD COLUMN IF NOT EXISTS alert_rules JSONB DEFAULT '{
  "airTemperatureMax": 35,
  "airTemperatureMin": 15,
  "airHumidityMax": 90,
  "airHumidityMin": 30,
  "soilMoistureMin": 40,
  "soilMoistureMax": 90,
  "lightLevelMin": 200
}'::jsonb;
