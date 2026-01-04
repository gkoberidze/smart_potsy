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
  verifyDeviceOwnership,
} from "./db";
import { config } from "./config";
import { sendPasswordResetEmail } from "./emailService";
import { AuthResponse } from "./types";
import { 
  ApiError, 
  ApiResponse, 
  successResponse, 
  errorHandler 
} from "./apiResponse";
import { 
  authLimiter, 
  resetLimiter, 
  generalLimiter 
} from "./rateLimiters";
import {
  assertDeviceAccess,
  validateLimit,
} from "./deviceHelpers";

const RegisterSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});

const LoginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
});

const QueryLimitSchema = z.object({
  limit: z
    .string()
    .optional()
    .default("100")
    .transform((v) => parseInt(v, 10))
    .pipe(z.number().int().positive().min(1).max(1000)),
});

const DeviceIdSchema = z.object({
  deviceId: z.string().regex(/^ESP32_\d{3}$/, "Invalid device ID format"),
});

const TelemetryQuerySchema = z.object({
  limit: z
    .string()
    .optional()
    .default("100")
    .transform((v) => parseInt(v, 10))
    .pipe(z.number().int().positive().min(1).max(1000)),
  since: z.string().datetime().optional(),
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

export const createHttpServer = (pool: Pool, logger: Logger) => {
  const app = express();

  // Security middleware
  app.use(helmet());
  app.use(
    cors({
      origin: "*",
    })
  );
  app.use(express.json({ limit: "1mb" }));
  app.use(
    pinoHttp({
      logger,
      autoLogging: true,
    })
  );

  // Rate limiting
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
      logger.warn({ errors: result.error.issues }, "Validation failed");
      res
        .status(400)
        .json({ error: "Invalid request body", details: result.error.issues });
      return;
    }
    next();
  };

  const validateQuery = (schema: z.ZodSchema) => (
    req: express.Request,
    res: express.Response,
    next: express.NextFunction
  ) => {
    const result = schema.safeParse({ ...req.query, ...req.params });
    if (!result.success) {
      logger.warn({ errors: result.error.issues }, "Validation failed");
      res
        .status(400)
        .json({ error: "Invalid request parameters", details: result.error.issues });
      return;
    }
    next();
  };

  app.get("/", (_req, res) => {
    res.json(
      successResponse({
        name: "Greenhouse IoT API",
        version: "0.1.0",
        endpoints: {
          health: "GET /health",
          auth: {
            register: "POST /api/auth/register",
            login: "POST /api/auth/login",
            oauth: "POST /api/auth/oauth",
            forgotPassword: "POST /api/auth/forgot-password",
            resetPassword: "POST /api/auth/reset-password",
            me: "GET /api/auth/me",
          },
          devices: {
            list: "GET /api/devices",
            register: "POST /api/devices",
            remove: "DELETE /api/devices/:deviceId",
            telemetry: "GET /api/devices/:deviceId/telemetry",
            status: "GET /api/devices/:deviceId/status",
          },
        },
      })
    );
  });

  app.get("/health", async (_req, res) => {
    try {
      await pool.query("SELECT 1");

      res.status(200).json(
        successResponse({
          status: "healthy",
          database: "connected",
        })
      );
    } catch (err) {
      logger.error({ err }, "Health check failed");
      res.status(503).json({
        success: false,
        error: {
          code: "DATABASE_ERROR",
          message: "Database connection failed",
          details: err instanceof Error ? err.message : "Unknown error",
        },
        timestamp: new Date().toISOString(),
      });
    }
  });

  app.post(
    "/api/auth/register",
    validateBody(RegisterSchema),
    async (req, res, next) => {
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
    }
  );

  app.post(
    "/api/auth/login",
    validateBody(LoginSchema),
    async (req, res, next) => {
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
    }
  );

  // OAuth login (Google/Facebook)
  const OAuthSchema = z.object({
    provider: z.enum(["google", "facebook"]),
    accessToken: z.string(),
  });

  app.post(
    "/api/auth/oauth",
    validateBody(OAuthSchema),
    async (req, res, next) => {
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
    }
  );

  // Forgot password
  const ForgotPasswordSchema = z.object({
    email: z.string().email(),
  });

  app.post(
    "/api/auth/forgot-password",
    validateBody(ForgotPasswordSchema),
    async (req, res, next) => {
      try {
        const { email } = req.body;

        const user = await getUserByEmail(email);

        // Always return success to prevent email enumeration
        if (!user) {
          res.json({ message: "If email exists, reset link sent" });
          return;
        }

        const resetToken = generateResetToken();
        const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

        await setResetToken(user.id, resetToken, expiresAt);

        // Send code directly instead of link
        const emailSent = await sendPasswordResetEmail(email, resetToken);
        if (!emailSent) {
          logger.info({ email, resetToken }, "SMTP not configured - reset code logged");
        }

        res.json({ message: "If email exists, reset link sent" });
      } catch (err) {
        logger.error({ err }, "Forgot password failed");
        next(err);
      }
    }
  );

  // Reset password
  const ResetPasswordSchema = z.object({
    token: z.string(),
    password: z.string().min(6),
  });

  app.post(
    "/api/auth/reset-password",
    validateBody(ResetPasswordSchema),
    async (req, res, next) => {
      try {
        const { token, password } = req.body;

        const user = await getUserByResetToken(token);

        if (!user) {
          res.status(400).json({ error: "Invalid or expired token" });
          return;
        }

        const passwordHash = await hashPassword(password);
        await updatePassword(user.id, passwordHash);

        res.json({ message: "Password reset successful" });
      } catch (err) {
        logger.error({ err }, "Reset password failed");
        next(err);
      }
    }
  );

  app.get("/api/auth/me", authMiddleware, async (req, res, next) => {
    try {
      const userId = (req as any).userId;
      const userEmail = (req as any).userEmail;
      res.json({
        user: {
          id: userId,
          email: userEmail,
        },
      });
    } catch (err) {
      logger.error({ err }, "Failed to get user info");
      next(err);
    }
  });

  app.get(
    "/api/devices",
    authMiddleware,
    validateQuery(QueryLimitSchema),
    async (req, res, next) => {
      const userId = (req as any).userId;
      const limit = Math.min(
        Math.max(parseInt((req.query.limit as string) ?? "100", 10) || 100, 1),
        500
      );

      try {
        const userDevices = await getUserDevices(userId);

        if (userDevices.length === 0) {
          res.json({ devices: [] });
          return;
        }

        const placeholders = userDevices
          .map((_, i) => `$${i + 1}`)
          .join(",");
        const { rows } = await pool.query(
          `
          SELECT DISTINCT ON (t.device_id)
            t.device_id,
            t.air_temperature,
            t.air_humidity,
            t.soil_temperature,
            t.soil_moisture,
            t.light_level,
            t.recorded_at,
            s.status,
            s.reported_at as status_reported_at
          FROM telemetry t
          LEFT JOIN device_status s ON s.device_id = t.device_id
          WHERE t.device_id IN (${placeholders})
          ORDER BY t.device_id, t.recorded_at DESC
          LIMIT $${userDevices.length + 1};
          `,
          [...userDevices, limit]
        );

        res.json({ devices: rows.map(toDeviceResponse) });
      } catch (err) {
        logger.error(
          {
            err,
            endpoint: "/api/devices",
            userId,
            limit,
            timestamp: new Date().toISOString(),
          },
          "Failed to fetch devices"
        );
        next(err);
      }
    }
  );

  const RegisterDeviceSchema = z.object({
    deviceId: z.string().min(1).max(100).regex(/^ESP32_\d{3}$/, "Device ID must match format ESP32_XXX"),
  });

  app.post(
    "/api/devices",
    authMiddleware,
    validateBody(RegisterDeviceSchema),
    async (req, res, next) => {
      const userId = (req as any).userId;
      const { deviceId } = req.body;

      try {
        const existingDevice = await pool.query(
          "SELECT user_id FROM devices WHERE device_id = $1",
          [deviceId]
        );

        if (existingDevice.rows.length > 0) {
          const existingUserId = existingDevice.rows[0].user_id;
          if (existingUserId !== 1 && existingUserId !== userId) {
            res.status(409).json({ error: "Device is already registered to another user" });
            return;
          }
          await pool.query(
            "UPDATE devices SET user_id = $1 WHERE device_id = $2",
            [userId, deviceId]
          );
        } else {
          await createDeviceForUser(deviceId, userId);
        }

        res.status(201).json({ deviceId, message: "Device registered successfully" });
      } catch (err) {
        logger.error({ err, deviceId, userId }, "Failed to register device");
        next(err);
      }
    }
  );

  app.delete(
    "/api/devices/:deviceId",
    authMiddleware,
    validateQuery(DeviceIdSchema),
    async (req, res, next) => {
      try {
        const userId = (req as any).userId;
        const { deviceId } = req.params as { deviceId: string };
        await assertDeviceAccess(pool, deviceId, userId);
        await pool.query("UPDATE devices SET user_id = 1 WHERE device_id = $1", [deviceId]);
        res.json(successResponse({ message: "Device removed from your account" }));
      } catch (err) {
        next(err);
      }
    }
  );

  app.get(
    "/api/devices/:deviceId/telemetry",
    authMiddleware,
    validateQuery(DeviceIdSchema.merge(TelemetryQuerySchema)),
    async (req, res, next) => {
      try {
        const userId = (req as any).userId;
        const { deviceId } = req.params as { deviceId: string };
        const limit = validateLimit(req.query.limit as string);

        await assertDeviceAccess(pool, deviceId, userId);

        const sinceParam = req.query.since as string | undefined;
        let query = `SELECT * FROM telemetry WHERE device_id = $1`;
        const params: any[] = [deviceId];

        if (sinceParam) {
          const parsed = new Date(sinceParam);
          if (!Number.isNaN(parsed.getTime())) {
            query += ` AND recorded_at > $2`;
            params.push(sinceParam);
          }
        }

        query += ` ORDER BY recorded_at DESC LIMIT ${Math.min(limit, 1000)}`;
        const result = await pool.query(query, params);
        const telemetry = result.rows.map(toTelemetryResponse);
        res.json(successResponse(telemetry));
      } catch (err) {
        next(err);
      }
    }
  );

  app.get(
    "/api/devices/:deviceId/status",
    authMiddleware,
    validateQuery(DeviceIdSchema),
    async (req, res, next) => {
      try {
        const userId = (req as any).userId;
        const { deviceId } = req.params as { deviceId: string };

        await assertDeviceAccess(pool, deviceId, userId);

        // Get device status
        const statusResult = await pool.query(
          "SELECT device_id, status, reported_at FROM device_status WHERE device_id = $1",
          [deviceId]
        );

        // Get latest telemetry
        const telemetryResult = await pool.query(
          `SELECT air_temperature, air_humidity, soil_temperature, soil_moisture, light_level, recorded_at 
           FROM telemetry WHERE device_id = $1 ORDER BY recorded_at DESC LIMIT 1`,
          [deviceId]
        );

        const status = statusResult.rows[0];
        const telemetry = telemetryResult.rows[0];

        // Check if online (status reported within last 2 minutes)
        const isOnline = status?.status === 'online' && status?.reported_at && 
          (Date.now() - new Date(status.reported_at).getTime()) < 2 * 60 * 1000;

        res.json(
          successResponse({
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
          })
        );
      } catch (err) {
        next(err);
      }
    }
  );

  // Notification endpoints
  app.post(
    "/api/notifications/register-token",
    authMiddleware,
    async (req, res, next) => {
      try {
        const userId = (req as any).userId;
        const { fcmToken } = req.body;

        if (!fcmToken) {
          throw new ApiError("FCM token is required", 400);
        }

        await pool.query(
          "UPDATE users SET fcm_token = $1 WHERE id = $2",
          [fcmToken, userId]
        );

        res.json(successResponse({ message: "Token registered successfully" }));
      } catch (err) {
        next(err);
      }
    }
  );

  app.get(
    "/api/notifications",
    authMiddleware,
    async (req, res, next) => {
      try {
        const userId = (req as any).userId;
        const limit = parseInt(req.query.limit as string) || 20;

        const result = await pool.query(
          `SELECT id, title, body, data, is_read, created_at 
           FROM notifications 
           WHERE user_id = $1 
           ORDER BY created_at DESC 
           LIMIT $2`,
          [userId, limit]
        );

        res.json(
          successResponse(
            result.rows.map((row) => ({
              id: row.id,
              title: row.title,
              body: row.body,
              data: row.data,
              isRead: row.is_read,
              createdAt: row.created_at,
            }))
          )
        );
      } catch (err) {
        next(err);
      }
    }
  );

  app.post(
    "/api/notifications/:id/read",
    authMiddleware,
    async (req, res, next) => {
      try {
        const userId = (req as any).userId;
        const { id } = req.params;

        const result = await pool.query(
          "UPDATE notifications SET is_read = TRUE WHERE id = $1 AND user_id = $2 RETURNING id",
          [id, userId]
        );

        if (result.rows.length === 0) {
          throw new ApiError("Notification not found", 404);
        }

        res.json(successResponse({ message: "Notification marked as read" }));
      } catch (err) {
        next(err);
      }
    }
  );

  // Alert rules endpoints
  app.get(
    "/api/devices/:deviceId/alert-rules",
    authMiddleware,
    async (req, res, next) => {
      try {
        const userId = (req as any).userId;
        const { deviceId } = req.params;

        await assertDeviceAccess(pool, deviceId, userId);

        const result = await pool.query(
          "SELECT alert_rules FROM devices WHERE device_id = $1",
          [deviceId]
        );

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
    }
  );

  app.post(
    "/api/devices/:deviceId/alert-rules",
    authMiddleware,
    async (req, res, next) => {
      try {
        const userId = (req as any).userId;
        const { deviceId } = req.params;
        const rules = req.body;

        await assertDeviceAccess(pool, deviceId, userId);

        await pool.query(
          "UPDATE devices SET alert_rules = $1 WHERE device_id = $2",
          [JSON.stringify(rules), deviceId]
        );

        res.json(successResponse({ message: "Alert rules updated successfully" }));
      } catch (err) {
        next(err);
      }
    }
  );

  // Error handler (must be last)
  app.use(errorHandler);

  return app;
};
