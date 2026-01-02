# Authentication & Device Ownership Guide

## Setup

All the JWT authentication and device ownership code has been scaffolded. Here's what was added:

### New Files
- `src/authService.ts` - JWT token generation/verification and password hashing

### Updated Files
- `config.ts` - Added JWT_SECRET and BCRYPT_ROUNDS config
- `.env` - Template with auth environment variables
- `types.ts` - User, Device, and Auth response types
- `db.ts` - User and device queries
- `migrations.ts` - Users and devices tables with foreign keys
- `httpServer.ts` - Auth endpoints and protected routes
- `mqttService.ts` - Auto-create devices with default system user

## API Endpoints

### Public Endpoints

#### Register
```bash
POST /api/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securepassword"
}

# Response
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "email": "user@example.com"
  }
}
```

#### Login
```bash
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securepassword"
}

# Response (same as register)
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "email": "user@example.com"
  }
}
```

### Protected Endpoints (Require Authorization Header)

All these endpoints now require a Bearer token:

```bash
Authorization: Bearer <your-jwt-token>
```

#### List User Devices
```bash
GET /api/devices
Authorization: Bearer <token>

# Response
{
  "devices": [
    {
      "deviceId": "ESP32_001",
      "lastTelemetry": {
        "airTemperature": 23.5,
        "airHumidity": 65,
        ...
      },
      "status": "online",
      "statusReportedAt": "2025-12-26T12:00:00Z"
    }
  ]
}
```

#### Get Device Telemetry
```bash
GET /api/devices/ESP32_001/telemetry?limit=100&since=2025-12-26T00:00:00Z
Authorization: Bearer <token>

# Response
{
  "telemetry": [
    {
      "deviceId": "ESP32_001",
      "airTemperature": 23.5,
      "airHumidity": 65,
      ...
    }
  ]
}
```

#### Get Device Status
```bash
GET /api/devices/ESP32_001/status
Authorization: Bearer <token>

# Response
{
  "deviceId": "ESP32_001",
  "status": "online",
  "reportedAt": "2025-12-26T12:00:00Z"
}
```

## How It Works

### Device Ownership Flow
1. User registers/logs in → Gets JWT token
2. MQTT device publishes data → Backend auto-creates device with system user (id=1)
3. User must register/login first, then devices can be assigned to them
4. Protected endpoints check device ownership before returning data

### Security
- Passwords hashed with bcrypt (10 rounds)
- JWT tokens expire in 7 days (configurable)
- Device access checks ownership (users can only see their devices)
- All protected endpoints validate Bearer token

## Environment Variables

Update `.env`:
```
JWT_SECRET=your-super-secret-key-min-32-characters-long
JWT_EXPIRES_IN=7d
BCRYPT_ROUNDS=10
```

## Next Steps

1. **Create system user** (id=1):
   ```sql
   INSERT INTO users (email, password_hash) VALUES ('system@greenhouse.local', '$2b$10$...');
   ```

2. **Assign devices to users** - Add endpoint to transfer device ownership:
   ```sql
   UPDATE devices SET user_id = ? WHERE device_id = ? AND user_id = 1;
   ```

3. **Add frontend login** - Use `/api/auth/login` to get token, store it, send in Authorization header

4. **Plant Health Logic** - Once auth is working, add health score calculations

## Testing

```bash
# Register
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# Login
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# Get devices (replace TOKEN with actual token)
curl http://localhost:3000/api/devices \
  -H "Authorization: Bearer TOKEN"
```
