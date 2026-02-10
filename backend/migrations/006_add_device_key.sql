-- Add device_key column for secure registration
-- device_id: ESP32_001, ESP32_002 (displayed to user)
-- device_key: GH-XXXX-XXXX (secret key for registration, in QR code and firmware)

ALTER TABLE devices 
ADD COLUMN IF NOT EXISTS device_key VARCHAR(50) UNIQUE;

-- Create index for fast lookup by key
CREATE INDEX IF NOT EXISTS idx_devices_device_key ON devices(device_key);

-- Update existing devices to have their device_id as device_key (migration)
UPDATE devices SET device_key = device_id WHERE device_key IS NULL;
