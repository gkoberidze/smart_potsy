DELETE FROM devices WHERE device_id IN ('GH-ACDE-6MSD', 'GH-DUWT-TEJX', 'GH-3DMW-FPHD', 'GH-KRNV-PYKU');
UPDATE devices SET user_id = 1 WHERE device_id = 'ESP32_001';
SELECT device_id, device_key, user_id FROM devices;
