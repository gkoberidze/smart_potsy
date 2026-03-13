# Smart Potsy - IoT Greenhouse Monitoring

Smart plant monitoring system: ESP32 sensors → MQTT → Node.js backend → PostgreSQL, with a Flutter mobile app.

## Architecture

```
ESP32 Sensors → EMQX (MQTT) → Node.js Backend → PostgreSQL
                                     ↑
                              Flutter App (HTTP)
```

## Project Structure

```
backend/          Node.js + TypeScript API server
firmware/         ESP32 Arduino sketch
smart_potsy/      Flutter mobile app
nginx/            Reverse proxy configs (production)
tools/            QR code generator for device keys
```

## Quick Start

### 1. Backend (Docker)
```bash
# Configure backend/.env (see backend/.env for required variables)
docker compose up -d --build
```

### 2. Verify
```bash
docker compose ps                    # All 3 services running
curl http://localhost:3000/health     # {"status":"healthy","database":"connected"}
```

### 3. Flutter App
```bash
cd smart_potsy
flutter pub get
flutter run
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| Backend API | 3000 | REST API + MQTT subscriber |
| PostgreSQL | 5432 | Data storage |
| EMQX | 1883 / 18083 | MQTT broker / Dashboard (admin/public) |

## API Endpoints

### Auth (public)
```
POST /api/auth/register          Register new user
POST /api/auth/login             Login (returns JWT)
POST /api/auth/oauth             OAuth login
POST /api/auth/forgot-password   Request password reset email
POST /api/auth/reset-password    Reset password with token
```

### Auth (requires JWT)
```
POST /api/auth/change-password   Change password
GET  /api/auth/me                Current user info
```

### Devices (requires JWT)
```
GET    /api/devices                          List user's devices
POST   /api/devices                          Register device with key (or QR scan)
DELETE /api/devices/:deviceId                Remove device
GET    /api/devices/:deviceId/telemetry      Telemetry history (?hours=24)
GET    /api/devices/:deviceId/status         Latest status
GET    /api/devices/:deviceId/alert-rules    Get alert thresholds
POST   /api/devices/:deviceId/alert-rules    Set alert thresholds
```

### Admin (requires ADMIN_API_KEY header)
```
POST /api/admin/devices/generate    Generate device keys (count, prefix)
```

## MQTT Topics

- `greenhouse/{deviceKey}/telemetry` — Sensor data every 60 seconds
- `greenhouse/{deviceKey}/status` — Online/offline (LWT)

Only registered device keys are accepted; unknown devices are rejected.

## Telemetry Format

```json
{
  "deviceId": "GH-XXXX-XXXX",
  "airTemperature": 25.5,
  "airHumidity": 65,
  "soilTemperature": 23.0,
  "soilMoisture": 45,
  "lightLevel": 78
}
```

All values are numeric. Light level is a percentage (0–100%).

## ESP32 Setup

Edit `firmware/esp32_greenhouse.ino`:
```cpp
const char *WIFI_SSID = "Your-WiFi";
const char *WIFI_PASSWORD = "Your-Password";
const char *MQTT_BROKER = "your-server-ip";
```

Flash the device key (generated via admin endpoint) before first use. Upload using Arduino IDE (Board: ESP32 Dev Module).

## Device Registration Flow

1. Admin generates device keys via API
2. Key is flashed to ESP32 firmware
3. User scans QR code or enters key manually in the app
4. ESP32 connects to MQTT and starts sending telemetry

## Backend Development (without Docker)
```bash
cd backend
npm install
npm run dev     # ts-node-dev with auto-reload
```
Requires PostgreSQL and EMQX accessible per `backend/.env`.

## Docker Commands
```bash
docker compose up -d --build         # Start all
docker compose logs -f backend       # Backend logs
docker compose ps                    # Service status
docker compose down                  # Stop all
```
