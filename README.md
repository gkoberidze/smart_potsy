# Greenhouse IoT - ESP32 → EMQX → Node.js → PostgreSQL

## Quick Start

### 1. Configure Environment
```bash
cp .env.example .env
# Edit .env with your database URL and MQTT settings
```

### 2. Start Docker
```bash
docker compose up -d --build
```

### 3. Check Services
```bash
docker compose logs -f backend      # Backend logs
docker compose ps                    # Service status
```

## Access Points

- **API**: `http://localhost:3000`
- **EMQX Dashboard**: `http://localhost:18083` (admin/public)
- **Health Check**: `GET http://localhost:3000/health`

## REST API Endpoints

```
GET  /health                                     → Service health
GET  /api/devices?limit=100                      → List all devices
GET  /api/devices/:deviceId/telemetry?limit=100 → Device telemetry history
GET  /api/devices/:deviceId/status               → Latest device status
```

## MQTT Topics

- `greenhouse/{deviceId}/telemetry` - Sensor data
- `greenhouse/{deviceId}/status` - Device online/offline

## ESP32 Setup

Edit `firmware/esp32_greenhouse.ino`:
```cpp
const char *WIFI_SSID = "YOUR_SSID";
const char *WIFI_PASSWORD = "YOUR_PASSWORD";
const char *MQTT_BROKER = "192.168.x.x"; // Your EMQX IP
const char *DEVICE_ID = "ESP32_001";
```

Upload to ESP32 using Arduino IDE.

## Stop Services
```bash
docker compose down
```

## Data Format

Telemetry JSON sent every 60 seconds:
```json
{
  "deviceId": "ESP32_001",
  "airTemperature": 25.5,
  "airHumidity": 65,
  "soilTemperature": 23.0,
  "soilMoisture": 45,
  "lightLevel": 750
}
```

Backend adds `recordedAt` timestamp when storing to database.
```bash
mosquitto_pub -h localhost -t greenhouse/ESP32_001/status -m "online"
mosquitto_pub -h localhost -t greenhouse/ESP32_001/telemetry -m '{"deviceId":"ESP32_001","airTemperature":24.2,"airHumidity":64,"soilTemperature":22.7,"soilMoisture":42,"lightLevel":710}'
```

## Firmware
- Example sketch: `firmware/esp32_greenhouse.ino`
- Uses `WiFi.h` and `PubSubClient`. Publishes telemetry every 60s and sets LWT `offline` status.
- Update `WIFI_SSID`, `WIFI_PASSWORD`, `MQTT_BROKER`, and optional MQTT credentials in the sketch before flashing.

## Backend development (without Docker)
```bash
cd backend
cp ../.env.example .env   # or create your own
npm install
npm run dev               # runs ts-node-dev with auto-reload
```
Ensure Postgres and EMQX are reachable per your `.env`.

## Database schema
- `telemetry`: time-series data with `device_id`, temps, humidity/moisture (%), light level, `recorded_at` (server timestamp). Indexed on `(device_id, recorded_at DESC)`.
- `device_status`: latest status per device with `reported_at` timestamp (upserts on each status message).

## Scaling & operations
- Built/tested for ~50 devices; tuned with pooled DB connections and indexed queries. Supports hundreds of devices by increasing EMQX and Postgres resources; adjust `Pool` size in `backend/src/db.ts` if needed.
- Enable MQTT authentication for production (set `EMQX_ALLOW_ANONYMOUS=false` and configure users in EMQX, then set `MQTT_USERNAME`/`MQTT_PASSWORD` in the backend env).
- Health endpoint (`/health`) suitable for container probes; add Docker healthchecks as desired.
- Logs are structured (pino) and output to stdout for container collection.

## Useful commands
- `docker compose down -v` → stop and remove local volumes.
- `docker compose exec db psql -U greenhouse -d greenhouse` → inspect data.
- `docker compose logs -f emqx` → broker logs.
