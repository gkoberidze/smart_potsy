# Greenhouse IoT API Documentation

## Base URL
```
http://localhost:3000
```

## Health Check
```
GET /health
```

### Response
```json
{
  "success": true,
  "data": {
    "status": "healthy",
    "database": "connected"
  },
  "timestamp": "2026-01-02T12:00:00.000Z"
}
```

---

## Authentication Endpoints

### Register
```
POST /api/auth/register
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": 1,
      "email": "user@example.com"
    }
  },
  "timestamp": "2026-01-02T12:00:00.000Z"
}
```

**Rate Limit:** 5 requests per 15 minutes

---

### Login
```
POST /api/auth/login
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": 1,
      "email": "user@example.com"
    }
  },
  "timestamp": "2026-01-02T12:00:00.000Z"
}
```

**Rate Limit:** 5 requests per 15 minutes

---

### Get Current User
```
GET /api/auth/me
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "email": "user@example.com"
  },
  "timestamp": "2026-01-02T12:00:00.000Z"
}
```

---

### Forgot Password
```
POST /api/auth/forgot-password
```

**Request Body:**
```json
{
  "email": "user@example.com"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "message": "Password reset email sent"
  },
  "timestamp": "2026-01-02T12:00:00.000Z"
}
```

**Rate Limit:** 3 requests per hour

---

### Reset Password
```
POST /api/auth/reset-password
```

**Request Body:**
```json
{
  "token": "resetTokenFromEmail",
  "password": "newPassword123"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "message": "Password reset successful"
  },
  "timestamp": "2026-01-02T12:00:00.000Z"
}
```

**Rate Limit:** 3 requests per hour

---

### OAuth Login
```
POST /api/auth/oauth
```

**Request Body:**
```json
{
  "provider": "google",
  "accessToken": "googleAccessToken"
}
```

**Provider Options:**
- `google`
- `facebook`

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": 1,
      "email": "user@example.com"
    }
  },
  "timestamp": "2026-01-02T12:00:00.000Z"
}
```

---

## Device Endpoints

All device endpoints require authentication via `Authorization: Bearer <token>` header.

### List Devices
```
GET /api/devices?limit=100
Authorization: Bearer <token>
```

**Query Parameters:**
- `limit` (optional): Number of devices to return (1-1000, default: 100)

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "deviceId": "ESP32_001",
      "lastTelemetry": {
        "airTemperature": 23.5,
        "airHumidity": 65,
        "soilTemperature": 18.2,
        "soilMoisture": 75,
        "lightLevel": 850,
        "recordedAt": "2026-01-02T12:00:00.000Z"
      },
      "status": "online",
      "statusReportedAt": "2026-01-02T12:00:00.000Z"
    }
  ],
  "timestamp": "2026-01-02T12:00:00.000Z"
}
```

---

### Register Device
```
POST /api/devices
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "deviceId": "ESP32_001"
}
```

**Device ID Format:** Must match `ESP32_XXX` where XXX are digits

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "deviceId": "ESP32_001"
  },
  "timestamp": "2026-01-02T12:00:00.000Z"
}
```

---

### Get Device Status
```
GET /api/devices/:deviceId/status
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "deviceId": "ESP32_001",
    "status": "online",
    "reportedAt": "2026-01-02T12:00:00.000Z"
  },
  "timestamp": "2026-01-02T12:00:00.000Z"
}
```

---

### Get Device Telemetry
```
GET /api/devices/:deviceId/telemetry?limit=100&since=2026-01-01T00:00:00Z
Authorization: Bearer <token>
```

**Query Parameters:**
- `limit` (optional): Number of records to return (1-1000, default: 100)
- `since` (optional): ISO 8601 timestamp to filter records from

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "deviceId": "ESP32_001",
      "airTemperature": 23.5,
      "airHumidity": 65,
      "soilTemperature": 18.2,
      "soilMoisture": 75,
      "lightLevel": 850,
      "recordedAt": "2026-01-02T12:00:00.000Z"
    }
  ],
  "timestamp": "2026-01-02T12:00:00.000Z"
}
```

---

### Remove Device
```
DELETE /api/devices/:deviceId
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "message": "Device removed successfully"
  },
  "timestamp": "2026-01-02T12:00:00.000Z"
}
```

---

## Error Handling

All errors follow this format:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable error message",
    "details": "Optional detailed information"
  },
  "timestamp": "2026-01-02T12:00:00.000Z"
}
```

### Common Error Codes
- `INVALID_REQUEST`: Invalid request body or parameters
- `AUTHENTICATION_ERROR`: Missing or invalid authentication token
- `AUTHORIZATION_ERROR`: User lacks permission for this resource
- `RESOURCE_NOT_FOUND`: Device or resource not found
- `CONFLICT`: Resource already exists
- `DATABASE_ERROR`: Database operation failed
- `INTERNAL_SERVER_ERROR`: Unexpected server error

### Status Codes
- `200 OK`: Successful request
- `201 Created`: Resource created successfully
- `400 Bad Request`: Invalid request parameters
- `401 Unauthorized`: Authentication required or failed
- `403 Forbidden`: Access denied
- `404 Not Found`: Resource not found
- `409 Conflict`: Resource conflict (e.g., duplicate email)
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error
- `503 Service Unavailable`: Service temporarily unavailable

---

## Rate Limiting

The API implements rate limiting on sensitive endpoints:

- **General endpoints**: 100 requests per 15 minutes
- **Auth login/register**: 5 requests per 15 minutes
- **Password reset**: 3 requests per hour

Rate limit info is included in response headers:
- `RateLimit-Limit`: Total allowed requests
- `RateLimit-Remaining`: Requests remaining
- `RateLimit-Reset`: Unix timestamp when limit resets

---

## Timestamps

All timestamps in responses are in ISO 8601 format with UTC timezone:
```
2026-01-02T12:00:00.000Z
```

Timestamps are generated by the backend server, not the client.

---

## Examples

### Register and Login Flow
```bash
# Register
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "securePassword123"
  }'

# Login
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "securePassword123"
  }'

# Get current user (using token from login response)
curl -X GET http://localhost:3000/api/auth/me \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIs..."
```

### Device Management Flow
```bash
# Register device
curl -X POST http://localhost:3000/api/devices \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{
    "deviceId": "ESP32_001"
  }'

# List devices
curl -X GET "http://localhost:3000/api/devices?limit=10" \
  -H "Authorization: Bearer TOKEN"

# Get telemetry
curl -X GET "http://localhost:3000/api/devices/ESP32_001/telemetry?limit=100" \
  -H "Authorization: Bearer TOKEN"
```
