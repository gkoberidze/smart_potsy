import cors from "cors";
import express from "express";
import helmet from "helmet";
import pinoHttp from "pino-http";
import { Pool } from "pg";
import { Logger } from "pino";
import { z } from "zod";
import {
  generateToken,
  generateResetToken,
  hashPassword,
  verifyPassword,
  verifyToken,
  verifyGoogleToken,
  verifyFacebookToken,
} from "./authService";
import {
  createDeviceForUser,
  createUser,
  createOAuthUser,
  getUserByEmail,
  getUserByResetToken,
  getUserDevices,
  setResetToken,
  updatePassword,
  updateUserOAuth,
} from "./db";
import { config } from "./config";
import { sendPasswordResetEmail } from "./emailService";
import { 
  ApiError, 
  successResponse, 
  errorHandler 
} from "./apiResponse";
import { 
  authLimiter, 
  resetLimiter, 
  generalLimiter 
} from "./rateLimiters";

// Simple helper to extract string from query params
const getString = (value: any): string | undefined => {
  if (typeof value === 'string') return value;
  if (Array.isArray(value) && value.length > 0) return String(value[0]);
  return undefined;
};

// Simple helper to extract number from query params
const getNumber = (value: any, defaultValue: number): number => {
  const str = getString(value);
  if (!str) return defaultValue;
  const num = parseInt(str, 10);
  return isNaN(num) ? defaultValue : num;
};

const RegisterSchema = z.object({
  email: z.string().email(),
  password: z.string()
    .min(8, "Password must be at least 8 characters")
    .regex(/[A-Z]/, "Password must contain at least one uppercase letter")
    .regex(/[a-z]/, "Password must contain at least one lowercase letter")
    .regex(/[0-9]/, "Password must contain at least one number")
    .regex(/[^A-Za-z0-9]/, "Password must contain at least one special character"),
});

const LoginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
});

const toTelemetryResponse = (row: Record<string, any>) => ({
  deviceId: row.device_id as string,
  airTemperature: row.air_temperature as number,
  airHumidity: row.air_humidity as number,
  soilTemperature: row.soil_temperature as number,
  soilMoisture: row.soil_moisture as number,
  lightLevel: row.light_level as number,
  recordedAt: row.recorded_at as string,
});

const toDeviceResponse = (row: Record<string, any>) => ({
  deviceId: row.device_id as string,
  lastTelemetry: row.recorded_at
    ? {
        airTemperature: row.air_temperature as number,
        airHumidity: row.air_humidity as number,
        soilTemperature: row.soil_temperature as number,
        soilMoisture: row.soil_moisture as number,
        lightLevel: row.light_level as number,
        recordedAt: row.recorded_at as string,
      }
    : null,
  status: row.status ?? null,
  statusReportedAt: row.status_reported_at as string | null,
});

const sendAuthResponse = (res: express.Response, user: any, statusCode = 200) => {
  const token = generateToken(user.id, user.email);
  res.status(statusCode).json(
    successResponse({
      token,
      user: { id: user.id, email: user.email },
    })
  );
};

const authMiddleware = async (
  req: express.Request,
  res: express.Response,
  next: express.NextFunction
) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      throw new ApiError(401, "MISSING_AUTH_HEADER", "Missing or invalid authorization header");
    }

    const token = authHeader.slice(7);
    const payload = verifyToken(token);
    (req as any).userId = payload.userId;
    (req as any).userEmail = payload.email;
    next();
  } catch (err) {
    next(new ApiError(401, "INVALID_TOKEN", "Invalid token"));
  }
};

const checkDeviceAccess = async (pool: Pool, deviceId: string, userId: number): Promise<boolean> => {
  const result = await pool.query("SELECT user_id FROM devices WHERE device_id = $1", [deviceId]);
  if (result.rows.length === 0) return false;
  const ownerId = result.rows[0].user_id;
  return ownerId === userId || ownerId === 1;
};

export const createHttpServer = (pool: Pool, logger: Logger) => {
  const app = express();

  app.use(helmet());
  app.use(cors({ origin: "*" }));
  app.use(express.json({ limit: "1mb" }));
  app.use(pinoHttp({ logger, autoLogging: true }));

  app.use("/api/auth/login", authLimiter);
  app.use("/api/auth/register", authLimiter);
  app.use("/api/auth/forgot-password", resetLimiter);
  app.use("/api/auth/reset-password", resetLimiter);
  app.use(generalLimiter);

  const validateBody = (schema: z.ZodSchema) => (
    req: express.Request,
    res: express.Response,
    next: express.NextFunction
  ) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: { code: "VALIDATION_ERROR", message: "Invalid request body", details: result.error.issues },
        timestamp: new Date().toISOString()
      });
    }
    next();
  };

  app.get("/", (_req, res) => {
    res.json(successResponse({ name: "Greenhouse IoT API", version: "0.1.0", status: "running" }));
  });

  app.get("/health", async (_req, res) => {
    try {
      await pool.query("SELECT 1");
      res.json(successResponse({ status: "healthy", database: "connected" }));
    } catch (err) {
      res.status(503).json({
        success: false,
        error: { code: "DATABASE_ERROR", message: "Database connection failed" },
        timestamp: new Date().toISOString()
      });
    }
  });

  app.post("/api/auth/register", validateBody(RegisterSchema), async (req, res, next) => {
    try {
      const { email, password } = req.body;
      const existingUser = await getUserByEmail(email);
      if (existingUser) {
        throw new ApiError(409, "USER_EXISTS", "User already exists");
      }

      const passwordHash = await hashPassword(password);
      const user = await createUser(email, passwordHash);
      sendAuthResponse(res, user, 201);
    } catch (err) {
      next(err);
    }
  });

  app.post("/api/auth/login", validateBody(LoginSchema), async (req, res, next) => {
    try {
      const { email, password } = req.body;
      const user = await getUserByEmail(email);
      if (!user || !user.password_hash) {
        throw new ApiError(401, "AUTH_FAILED", "Invalid email or password");
      }

      const passwordValid = await verifyPassword(password, user.password_hash);
      if (!passwordValid) {
        throw new ApiError(401, "AUTH_FAILED", "Invalid email or password");
      }

      sendAuthResponse(res, user);
    } catch (err) {
      next(err);
    }
  });

  const OAuthSchema = z.object({
    provider: z.enum(["google", "facebook"]),
    accessToken: z.string(),
  });

  app.post("/api/auth/oauth", validateBody(OAuthSchema), async (req, res, next) => {
    try {
      const { provider, accessToken } = req.body;
      const verifier = provider === "google" ? verifyGoogleToken : verifyFacebookToken;
      const oauthData = await verifier(accessToken);
      if (!oauthData) {
        throw new ApiError(401, "INVALID_OAUTH_TOKEN", "Invalid OAuth token");
      }

      let user = await getUserByEmail(oauthData.email);
      if (!user) {
        user = await createOAuthUser(oauthData.email, provider, oauthData.id);
      } else {
        await updateUserOAuth(oauthData.email, provider, oauthData.id);
      }

      sendAuthResponse(res, user);
    } catch (err) {
      next(err);
    }
  });

  const ForgotPasswordSchema = z.object({ email: z.string().email() });

  app.post("/api/auth/forgot-password", validateBody(ForgotPasswordSchema), async (req, res, next) => {
    try {
      const { email } = req.body;
      const user = await getUserByEmail(email);
      
      if (!user) {
        res.json(successResponse({ message: "If email exists, reset link sent" }));
        return;
      }

      const resetToken = generateResetToken();
      const expiresAt = new Date(Date.now() + 60 * 60 * 1000);
      await setResetToken(user.id, resetToken, expiresAt);
      await sendPasswordResetEmail(email, resetToken);

      res.json(successResponse({ message: "If email exists, reset link sent" }));
    } catch (err) {
      next(err);
    }
  });

  const ResetPasswordSchema = z.object({
    token: z.string(),
    password: z.string().min(6),
  });

  app.post("/api/auth/reset-password", validateBody(ResetPasswordSchema), async (req, res, next) => {
    try {
      const { token, password } = req.body;
      const user = await getUserByResetToken(token);

      if (!user) {
        throw new ApiError(400, "INVALID_TOKEN", "Invalid or expired token");
      }

      const passwordHash = await hashPassword(password);
      await updatePassword(user.id, passwordHash);

      res.json(successResponse({ message: "Password reset successful" }));
    } catch (err) {
      next(err);
    }
  });

  const ChangePasswordSchema = z.object({
    currentPassword: z.string(),
    newPassword: z.string()
      .min(8, "Password must be at least 8 characters")
      .regex(/[A-Z]/, "Password must contain at least one uppercase letter")
      .regex(/[a-z]/, "Password must contain at least one lowercase letter")
      .regex(/[0-9]/, "Password must contain at least one number")
      .regex(/[^A-Za-z0-9]/, "Password must contain at least one special character"),
  });

  app.post("/api/auth/change-password", authMiddleware, validateBody(ChangePasswordSchema), async (req, res, next) => {
    try {
      const userId = (req as any).userId;
      const { currentPassword, newPassword } = req.body;

      const result = await pool.query({ text: "SELECT id, password_hash FROM users WHERE id = $1", values: [userId] });

      if (result.rows.length === 0) {
        throw new ApiError(404, "USER_NOT_FOUND", "User not found");
      }

      const user = result.rows[0];
      const isValid = await verifyPassword(currentPassword, user.password_hash);
      if (!isValid) {
        throw new ApiError(401, "INVALID_PASSWORD", "Current password is incorrect");
      }

      const newPasswordHash = await hashPassword(newPassword);
      await updatePassword(userId, newPasswordHash);

      res.json(successResponse({ message: "Password changed successfully" }));
    } catch (err) {
      next(err);
    }
  });

  app.get("/api/auth/me", authMiddleware, async (req, res) => {
    const userId = (req as any).userId;
    const userEmail = (req as any).userEmail;
    res.json(successResponse({ id: userId, email: userEmail }));
  });

  app.get("/api/devices", authMiddleware, async (req, res, next) => {
    const userId = (req as any).userId;
    const limit = Math.min(getNumber(req.query.limit, 100), 500);

    try {
      const userDevices = await getUserDevices(userId);

      if (userDevices.length === 0) {
        res.json(successResponse({ devices: [] }));
        return;
      }

      const placeholders = userDevices.map((_, i) => `$${i + 1}`).join(",");
      const { rows } = await pool.query(
        `SELECT DISTINCT ON (t.device_id)
          t.device_id, t.air_temperature, t.air_humidity, t.soil_temperature,
          t.soil_moisture, t.light_level, t.recorded_at,
          s.status, s.reported_at as status_reported_at
        FROM telemetry t
        LEFT JOIN device_status s ON s.device_id = t.device_id
        WHERE t.device_id IN (${placeholders})
        ORDER BY t.device_id, t.recorded_at DESC
        LIMIT $${userDevices.length + 1}`,
        [...userDevices, limit]
      );

      res.json(successResponse({ devices: rows.map(toDeviceResponse) }));
    } catch (err) {
      next(err);
    }
  });

  const generateDeviceKey = (): string => {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    const part = () => Array.from({ length: 4 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
    return `GH-${part()}-${part()}`;
  };

  const RegisterDeviceSchema = z.object({
    deviceId: z.string().regex(/^GH-[A-Z0-9]{4}-[A-Z0-9]{4}$/).optional(),
  });

  app.post("/api/devices", authMiddleware, validateBody(RegisterDeviceSchema), async (req, res, next) => {
    const userId = (req as any).userId;
    let { deviceId } = req.body;

    if (!deviceId) {
      deviceId = generateDeviceKey();
      let attempts = 0;
      while (attempts < 10) {
        const existing = await pool.query({ text: "SELECT 1 FROM devices WHERE device_id = $1", values: [deviceId] });
        if (existing.rows.length === 0) break;
        deviceId = generateDeviceKey();
        attempts++;
      }
    }

    try {
      const existingDevice = await pool.query({
        text: "SELECT user_id FROM devices WHERE device_id = $1",
        values: [deviceId]
      });

      if (existingDevice.rows.length > 0) {
        const existingUserId = existingDevice.rows[0].user_id;
        if (existingUserId !== 1 && existingUserId !== userId) {
          throw new ApiError(409, "DEVICE_TAKEN", "Device is already registered to another user");
        }
        await pool.query({ text: "UPDATE devices SET user_id = $1 WHERE device_id = $2", values: [userId, deviceId] });
      } else {
        await createDeviceForUser(deviceId, userId);
      }

      const deviceResult = await pool.query({
        text: "SELECT device_id, user_id, created_at FROM devices WHERE device_id = $1",
        values: [deviceId]
      });

      res.status(201).json(successResponse(deviceResult.rows[0]));
    } catch (err) {
      next(err);
    }
  });

  app.delete("/api/devices/:deviceId", authMiddleware, async (req, res, next) => {
    try {
      const userId = (req as any).userId;
      const deviceId = getString(req.params.deviceId);
      if (!deviceId) {
        throw new ApiError(400, "INVALID_DEVICE_ID", "Device ID is required");
      }
      
      const hasAccess = await checkDeviceAccess(pool, deviceId, userId);
      if (!hasAccess) {
        throw new ApiError(403, "FORBIDDEN", "Access denied to this device");
      }

      await pool.query({ text: "UPDATE devices SET user_id = 1 WHERE device_id = $1", values: [deviceId] });
      res.json(successResponse({ message: "Device removed from your account" }));
    } catch (err) {
      next(err);
    }
  });

  app.get("/api/devices/:deviceId/telemetry", authMiddleware, async (req, res, next) => {
    try {
      const userId = (req as any).userId;
      const deviceId = getString(req.params.deviceId);
      if (!deviceId) {
        throw new ApiError(400, "INVALID_DEVICE_ID", "Device ID is required");
      }
      
      const limit = Math.min(getNumber(req.query.limit, 100), 1000);

      const hasAccess = await checkDeviceAccess(pool, deviceId, userId);
      if (!hasAccess) {
        throw new ApiError(403, "FORBIDDEN", "Access denied to this device");
      }

      const sinceParam = getString(req.query.since);
      let query = `SELECT * FROM telemetry WHERE device_id = $1`;
      const params: any[] = [deviceId];

      if (sinceParam) {
        const parsed = new Date(sinceParam);
        if (!Number.isNaN(parsed.getTime())) {
          query += ` AND recorded_at > $2`;
          params.push(sinceParam);
        }
      }

      query += ` ORDER BY recorded_at DESC LIMIT ${limit}`;
      const result = await pool.query({ text: query, values: params });
      const telemetry = result.rows.map(toTelemetryResponse);
      res.json(successResponse(telemetry));
    } catch (err) {
      next(err);
    }
  });

  app.get("/api/devices/:deviceId/status", authMiddleware, async (req, res, next) => {
    try {
      const userId = (req as any).userId;
      const deviceId = getString(req.params.deviceId);
      if (!deviceId) {
        throw new ApiError(400, "INVALID_DEVICE_ID", "Device ID is required");
      }

      const hasAccess = await checkDeviceAccess(pool, deviceId, userId);
      if (!hasAccess) {
        throw new ApiError(403, "FORBIDDEN", "Access denied to this device");
      }

      const statusResult = await pool.query(
        "SELECT device_id, status, reported_at FROM device_status WHERE device_id = $1",
        [deviceId]
      );

      const telemetryResult = await pool.query(
        `SELECT air_temperature, air_humidity, soil_temperature, soil_moisture, light_level, recorded_at 
         FROM telemetry WHERE device_id = $1 ORDER BY recorded_at DESC LIMIT 1`,
        [deviceId]
      );

      const status = statusResult.rows[0];
      const telemetry = telemetryResult.rows[0];

      const isOnline = status?.status === 'online' && status?.reported_at && 
        (Date.now() - new Date(status.reported_at).getTime()) < 2 * 60 * 1000;

      res.json(successResponse({
        online: isOnline,
        lastSeen: status?.reported_at || telemetry?.recorded_at || null,
        latestTelemetry: telemetry ? {
          airTemperature: telemetry.air_temperature,
          airHumidity: telemetry.air_humidity,
          soilTemperature: telemetry.soil_temperature,
          soilMoisture: telemetry.soil_moisture,
          lightLevel: telemetry.light_level,
          recordedAt: telemetry.recorded_at,
        } : null,
      }));
    } catch (err) {
      next(err);
    }
  });

  app.get("/api/devices/:deviceId/alert-rules", authMiddleware, async (req, res, next) => {
    try {
      const userId = (req as any).userId;
      const deviceId = getString(req.params.deviceId);
      if (!deviceId) {
        throw new ApiError(400, "INVALID_DEVICE_ID", "Device ID is required");
      }

      const hasAccess = await checkDeviceAccess(pool, deviceId, userId);
      if (!hasAccess) {
        throw new ApiError(403, "FORBIDDEN", "Access denied to this device");
      }

      const result = await pool.query({
        text: "SELECT alert_rules FROM devices WHERE device_id = $1",
        values: [deviceId]
      });

      const rules = result.rows[0]?.alert_rules || {
        airTemperatureMax: 35,
        airTemperatureMin: 15,
        airHumidityMax: 90,
        airHumidityMin: 30,
        soilMoistureMin: 40,
        soilMoistureMax: 90,
        lightLevelMin: 200,
      };

      res.json(successResponse(rules));
    } catch (err) {
      next(err);
    }
  });

  app.post("/api/devices/:deviceId/alert-rules", authMiddleware, async (req, res, next) => {
    try {
      const userId = (req as any).userId;
      const deviceId = getString(req.params.deviceId);
      if (!deviceId) {
        throw new ApiError(400, "INVALID_DEVICE_ID", "Device ID is required");
      }
      
      const rules = req.body;

      const hasAccess = await checkDeviceAccess(pool, deviceId, userId);
      if (!hasAccess) {
        throw new ApiError(403, "FORBIDDEN", "Access denied to this device");
      }

      await pool.query({
        text: "UPDATE devices SET alert_rules = $1 WHERE device_id = $2",
        values: [JSON.stringify(rules), deviceId]
      });

      res.json(successResponse({ message: "Alert rules updated successfully" }));
    } catch (err) {
      next(err);
    }
  });

  app.use(errorHandler);

  return app;
}