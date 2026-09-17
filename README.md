# Smart Potsy - Smart Plant Monitoring

Smart plant monitoring system: ESP32 sensors → MQTT → Node.js backend → PostgreSQL, with a Flutter mobile app. The current stack has no blockchain or Solana dependency.

## Architecture

```
ESP32 Sensors → EMQX (MQTT) → Node.js Backend → PostgreSQL
                                     ↑
                              Flutter App (HTTP API)
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

### 1. Start the backend stack
```bash
# Configure backend/.env with local values before starting.
docker compose up -d --build
```

### 2. Verify
```bash
docker compose ps                    # All 3 services running
curl http://localhost:3000/health     # healthy response from the API
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
| EMQX | 1883 / 18083 | MQTT broker / Dashboard (local development) |

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
POST /api/admin/devices/generate    Generate device keys (count)
```

## MQTT Topics

- `smart-potsy/{deviceId}/telemetry` — Sensor data every 60 seconds
- `smart-potsy/{deviceId}/status` — Online/offline (LWT)

Only registered device keys are accepted; unknown devices are rejected.

## Telemetry Format

```json
{
  "deviceId": "ESP32_001",
  "deviceKey": "GH-XXXX-XXXX",
  "airTemperature": 25.5,
  "airHumidity": 65,
  "soilTemperature": 23.0,
  "soilMoisture": 45,
  "lightLevel": 700
}
```

All values are numeric. Air humidity and soil moisture are percentages (0–100%); light level is the raw sensor reading.

## ESP32 Setup

Copy `firmware/credentials.h.example` to `firmware/credentials.h`, fill in the local Wi-Fi, MQTT, device ID, and device key values, then flash `firmware/smart_potsy_esp32.ino`:
```cpp
const char *DEVICE_ID = "ESP32_003";
const char *DEVICE_KEY = "GH-XXXX-XXXX";
```

Flash the device ID and device key before first use. The MQTT broker address must be reachable from the ESP32; `localhost` refers to the ESP32 itself, not the Docker host. Upload using Arduino IDE (Board: ESP32 Dev Module).

## Device Registration Flow

1. Admin generates a device key via the API
2. The key is flashed to the ESP32 firmware
3. A user creates an account and signs in to the Flutter app
4. The user scans the QR code or enters the device key manually
5. The ESP32 connects to MQTT and starts sending telemetry
6. The backend stores accepted readings in PostgreSQL and the app reads them through the API

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
