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
  getAllUsers,  // Add this import if it's defined in db.ts
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

const QueryLimitSchema = z.object({
  limit: z
    .string()
    .optional()
    .default("100")
    .transform((v) => parseInt(v, 10))
    .pipe(z.number().int().positive().min(1).max(1000)),
});

const DeviceIdSchema = z.object({
  deviceId: z.string().regex(/^GH-[A-Z0-9]{4}-[A-Z0-9]{4}$/, "Invalid device ID format"),
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

const authMiddleware = (
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

// Admin user IDs (add your admin user id here)
const ADMIN_USER_IDS = [1]; // Update with your admin user id(s)

// Admin middleware
const adminMiddleware = (req: express.Request, res: express.Response, next: express.NextFunction) => {
  const userId = (req as any).userId;
  if (!ADMIN_USER_IDS.includes(userId)) {
    return res.status(403).json({ error: "Forbidden: Admins only" });
  }
  next();
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

  app.get("/", (_req: express.Request, res: express.Response) => {
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

  app.get("/health", async (_req: express.Request, res: express.Response) => {
    try {
      await pool.query("SELECT 1");

      res.status(200).json(
        successResponse({
          status: "healthy",
          database: "connected",
        })
      );
    } catch (err) {
      res.status(500).json({ error: "Database connection failed" });
    }
  });

  // List all users (admin only)
  app.get("/api/admin/users", authMiddleware, adminMiddleware, async (_req: express.Request, res: express.Response, next: express.NextFunction) => {
    try {
      const users = await getAllUsers();
      res.json(successResponse({ users }));
    } catch (err) {
      next(err);
    }
  });

  // User registration
  app.post(
    "/api/auth/register",
    validateBody(RegisterSchema),
    async (req: express.Request, res: express.Response, next: express.NextFunction) => {
      try {
        const { email, password } = req.body;
        // Check if user already exists
        const existingUser = await getUserByEmail(email);
        if (existingUser) {
          return res.status(409).json({ error: "User already exists" });
        }
        // Hash password and create user
        const hashedPassword = await hashPassword(password);
        const user = await createUser(email, hashedPassword);
        sendAuthResponse(res, user, 201);
      } catch (err) {
        next(err);
      }
    }
  );

  // ... (rest of your routes and code here, truncated in the original)

  // Error handler (must be last)
  app.use(errorHandler);

  return app;
};