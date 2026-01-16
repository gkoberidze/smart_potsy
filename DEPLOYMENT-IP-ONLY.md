# 🌱 IP-Only Deployment Guide (No Domain)

This guide is for deploying to a DigitalOcean server with only an IP address (no domain).

## 📋 Prerequisites

- Ubuntu 22.04 server (DigitalOcean droplet)
- Server IP: `161.35.219.50`
- SSH access to server

---

## 🚀 Quick Deployment (5 minutes)

### 1. SSH into your server

```bash
ssh root@161.35.219.50
```

### 2. Clone your project

```bash
git clone <your-github-repo-url>
cd greenhouse-iot
```

### 3. Run deployment script

```bash
chmod +x deploy-ip-only.sh
sudo ./deploy-ip-only.sh
```

The script will:
- ✅ Create `.env` file with auto-generated passwords
- ✅ Install Docker & Docker Compose
- ✅ Configure firewall (ports 80, 3000, 1883)
- ✅ Start all services

---

## 📝 Manual Setup (if script doesn't work)

### 1. Create `.env` file

```bash
cat > .env << EOF
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
JWT_SECRET=$(openssl rand -hex 64)
SERVER_IP=161.35.219.50
EOF
```

### 2. Start services

```bash
docker-compose -f docker-compose.ip-only.yml up -d --build
```

### 3. Configure firewall

```bash
ufw allow 80/tcp
ufw allow 3000/tcp
ufw allow 1883/tcp
ufw allow 22/tcp
ufw enable
```

---

## ✅ Verify Deployment

### Test API

```bash
curl http://161.35.219.50:3000/health
```

Expected response:
```json
{
  "success": true,
  "data": {
    "status": "healthy",
    "database": "connected"
  }
}
```

### Test MQTT

```bash
mosquitto_pub -h 161.35.219.50 -p 1883 -t "greenhouse/TEST-0001-0001/status" -m "online"
```

---

## 📱 Flutter App Configuration

Your Flutter app is already configured to use:
```dart
static const String baseUrl = 'http://161.35.219.50';
```

**Update to use port 3000:**
```dart
static const String baseUrl = 'http://161.35.219.50:3000';
```

---

## 🔧 ESP32 Configuration

Update `firmware/esp32_greenhouse.ino`:

```cpp
const char *WIFI_SSID = "YOUR_WIFI_NAME";
const char *WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
const char *MQTT_BROKER = "161.35.219.50";  // Your server IP
const uint16_t MQTT_PORT = 1883;
const char *DEVICE_KEY = "GH-XXXX-XXXX";  // Generate in Flutter app first!
```

---

## 📊 Service Ports

| Service | Port | URL |
|---------|------|-----|
| Backend API | 3000 | `http://161.35.219.50:3000` |
| MQTT Broker | 1883 | `161.35.219.50:1883` |
| EMQX Dashboard | 18083 | `http://161.35.219.50:18083` |

---

## 🔍 Troubleshooting

### Check if services are running

```bash
docker-compose -f docker-compose.ip-only.yml ps
```

### View logs

```bash
# All services
docker-compose -f docker-compose.ip-only.yml logs -f

# Specific service
docker-compose -f docker-compose.ip-only.yml logs -f backend
docker-compose -f docker-compose.ip-only.yml logs -f emqx
```

### Restart services

```bash
docker-compose -f docker-compose.ip-only.yml restart
```

### Stop services

```bash
docker-compose -f docker-compose.ip-only.yml down
```

---

## 🔐 Security Notes

⚠️ **Important**: Without SSL/HTTPS:
- All traffic is unencrypted (HTTP, not HTTPS)
- Passwords sent in plain text
- Not recommended for production with sensitive data

**For production**, consider:
1. Getting a free domain (e.g., from Freenom, No-IP)
2. Setting up SSL with Let's Encrypt
3. Using the full `deploy.sh` script

---

## 📡 Data Flow

```
ESP32 Sensor (WiFi)
    ↓
    ↓ MQTT: greenhouse/{deviceId}/telemetry
    ↓ Port 1883
EMQX MQTT Broker (161.35.219.50:1883)
    ↓
Node.js Backend (receives & stores)
    ↓
PostgreSQL Database
    ↓
Flutter App (fetches via HTTP API)
    ↓ Port 3000
    ↓ http://161.35.219.50:3000/api/devices
User sees data! 📱
```

---

## ✅ Checklist

- [ ] Server deployed and running
- [ ] API health check works: `curl http://161.35.219.50:3000/health`
- [ ] MQTT broker accessible on port 1883
- [ ] Flutter app updated with server IP
- [ ] ESP32 firmware configured with server IP
- [ ] Device registered in Flutter app
- [ ] ESP32 sending data successfully

---

## 🎉 You're Done!

Your ESP32 sensors will now send data to your server, and your Flutter app will display it in real-time!
