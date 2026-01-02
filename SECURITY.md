# Configuration Guide

## Backend Setup

Create `.env` file from `.env.example`:

```bash
DATABASE_URL=postgresql://user:password@db:5432/greenhouse
MQTT_URL=mqtt://emqx:1883
MQTT_USERNAME=your-username
MQTT_PASSWORD=your-password
NODE_ENV=production
PORT=3000
LOG_LEVEL=info
```

Never commit `.env` to git - add to `.gitignore`.

## ESP32 Firmware Setup

Edit `firmware/esp32_greenhouse.ino` and set:

```cpp
const char *WIFI_SSID = "Your-WiFi-Name";
const char *WIFI_PASSWORD = "Your-WiFi-Password";
const char *MQTT_BROKER = "192.168.x.x";      // EMQX server IP
const char *DEVICE_ID = "ESP32_001";           // Unique ID
const char *MQTT_USERNAME = "your-user";       // If EMQX requires auth
const char *MQTT_PASSWORD = "your-password";   // If EMQX requires auth
```

Upload to ESP32 using Arduino IDE (Board: ESP32 Dev Module).

## MQTT Topics Published

- `greenhouse/ESP32_001/telemetry` - Sensor data every 60 seconds
- `greenhouse/ESP32_001/status` - Online/offline status

Monitor in EMQX Dashboard (http://localhost:18083).

## Docker Commands

```bash
# Start all services
docker compose up -d --build

# View logs
docker compose logs -f backend
docker compose logs -f emqx

# Stop all services
docker compose down

# View service status
docker compose ps
```

