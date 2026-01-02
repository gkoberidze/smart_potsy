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
  deviceId: z.string().min(1).max(100),
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

const authMiddleware = async (
  req: express.Request,
  res: express.Response,
  next: express.NextFunction
) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      res.status(401).json({ error: "Missing or invalid authorization header" });
      return;
    }

    const token = authHeader.slice(7);
    const payload = verifyToken(token);
    (req as any).userId = payload.userId;
    (req as any).userEmail = payload.email;
    next();
  } catch (err) {
    res.status(401).json({ error: "Invalid token" });
  }
};

export const createHttpServer = (pool: Pool, logger: Logger) => {
  const app = express();

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
    res.json({
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
    });
  });

  app.get("/health", async (_req, res) => {
    try {
      await pool.query("SELECT 1");

      res.status(200).json({
        status: "healthy",
        database: "connected",
        timestamp: new Date().toISOString(),
      });
    } catch (err) {
      logger.error({ err }, "Health check failed");
      res.status(503).json({
        status: "unhealthy",
        database: "disconnected",
        error: err instanceof Error ? err.message : "Unknown error",
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
          res.status(409).json({ error: "User already exists" });
          return;
        }

        const passwordHash = await hashPassword(password);
        const user = await createUser(email, passwordHash);

        const token = generateToken(user.id, user.email);
        const response: AuthResponse = {
          token,
          user: {
            id: user.id,
            email: user.email,
          },
        };

        res.status(201).json(response);
      } catch (err) {
        logger.error({ err }, "Registration failed");
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
        if (!user) {
          res.status(401).json({ error: "Invalid email or password" });
          return;
        }

        if (!user.password_hash) {
          res.status(401).json({ error: "Please login with Google or Facebook" });
          return;
        }

        const passwordValid = await verifyPassword(password, user.password_hash);
        if (!passwordValid) {
          res.status(401).json({ error: "Invalid email or password" });
          return;
        }

        const token = generateToken(user.id, user.email);
        const response: AuthResponse = {
          token,
          user: {
            id: user.id,
            email: user.email,
          },
        };

        res.json(response);
      } catch (err) {
        logger.error({ err }, "Login failed");
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

        let oauthData: { email: string; id: string } | null = null;

        if (provider === "google") {
          oauthData = await verifyGoogleToken(accessToken);
        } else if (provider === "facebook") {
          oauthData = await verifyFacebookToken(accessToken);
        }

        if (!oauthData) {
          res.status(401).json({ error: "Invalid OAuth token" });
          return;
        }

        let user = await getUserByEmail(oauthData.email);

        if (!user) {
          user = await createOAuthUser(oauthData.email, provider, oauthData.id);
        } else {
          await updateUserOAuth(oauthData.email, provider, oauthData.id);
        }

        const token = generateToken(user.id, user.email);
        const response: AuthResponse = {
          token,
          user: {
            id: user.id,
            email: user.email,
          },
        };

        res.json(response);
      } catch (err) {
        logger.error({ err }, "OAuth login failed");
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
      const userId = (req as any).userId;
      const { deviceId } = req.params as { deviceId: string };

      try {
        const hasAccess = await verifyDeviceOwnership(deviceId, userId);
        if (!hasAccess) {
          res.status(403).json({ error: "Access denied" });
          return;
        }

        await pool.query(
          "UPDATE devices SET user_id = 1 WHERE device_id = $1",
          [deviceId]
        );

        res.json({ message: "Device removed from your account" });
      } catch (err) {
        logger.error({ err, deviceId, userId }, "Failed to remove device");
        next(err);
      }
    }
  );

  app.get(
    "/api/devices/:deviceId/telemetry",
    authMiddleware,
    validateQuery(DeviceIdSchema.merge(TelemetryQuerySchema)),
    async (req, res, next) => {
      const userId = (req as any).userId;
      const { deviceId } = req.params as { deviceId: string };
      const limit = Math.min(
        Math.max(parseInt((req.query.limit as string) ?? "100", 10) || 100, 1),
        1000
      );

      try {
        const hasAccess = await verifyDeviceOwnership(deviceId, userId);
        if (!hasAccess) {
          res.status(403).json({ error: "Access denied" });
          return;
        }

        const sinceParam = req.query.since as string | undefined;
        let sinceDate: Date | undefined;
        if (sinceParam) {
          const parsed = new Date(sinceParam);
          if (!Number.isNaN(parsed.getTime())) {
            sinceDate = parsed;
          }
        }

        const { rows } = await pool.query(
          `
          SELECT 
            device_id,
            air_temperature,
            air_humidity,
            soil_temperature,
            soil_moisture,
            light_level,
            recorded_at
          FROM telemetry
          WHERE device_id = $1
          ${sinceDate ? "AND recorded_at >= $3" : ""}
          ORDER BY recorded_at DESC
          LIMIT $2;
          `,
          sinceDate ? [deviceId, limit, sinceDate] : [deviceId, limit]
        );

        res.json({ telemetry: rows.map(toTelemetryResponse) });
      } catch (err) {
        logger.error(
          {
            err,
            deviceId,
            userId,
            limit,
            endpoint: "/api/devices/:deviceId/telemetry",
            timestamp: new Date().toISOString(),
          },
          "Failed to fetch telemetry"
        );
        next(err);
      }
    }
  );

  app.get(
    "/api/devices/:deviceId/status",
    authMiddleware,
    validateQuery(DeviceIdSchema),
    async (req, res, next) => {
      const userId = (req as any).userId;
      try {
        const { deviceId } = req.params as { deviceId: string };

        const hasAccess = await verifyDeviceOwnership(deviceId, userId);
        if (!hasAccess) {
          res.status(403).json({ error: "Access denied" });
          return;
        }

        const { rows } = await pool.query(
          `SELECT device_id, status, reported_at FROM device_status WHERE device_id = $1;`,
          [deviceId]
        );

        if (rows.length === 0) {
          logger.info({ deviceId }, "Device not found");
          res.status(404).json({ error: "Device not found" });
          return;
        }

        const row = rows[0];
        res.json({
          deviceId: row.device_id,
          status: row.status,
          reportedAt: row.reported_at,
        });
      } catch (err) {
        const deviceId = (req.params as { deviceId?: string }).deviceId || "unknown";
        const userId = (req as any).userId;
        logger.error(
          {
            err,
            deviceId,
            userId,
            endpoint: "/api/devices/:deviceId/status",
            timestamp: new Date().toISOString(),
          },
          "Failed to fetch device status"
        );
        next(err);
      }
    }
  );

  // Error handler
  app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    logger.error({ err }, "Unhandled error");
    res.status(500).json({ error: "Internal server error" });
  });

  return app;
};
