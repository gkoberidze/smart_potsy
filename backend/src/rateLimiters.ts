import rateLimit from "express-rate-limit";
import { Request, Response } from "express";

// Custom handler to return JSON
const jsonHandler = (message: string) => (req: Request, res: Response) => {
  res.status(429).json({ success: false, error: message });
};

// General API rate limiter
export const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  handler: jsonHandler("Too many requests from this IP, please try again later."),
  standardHeaders: true,
  legacyHeaders: false,
});

// Auth endpoints (stricter)
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // Limit each IP to 10 requests per windowMs (increased for development)
  handler: jsonHandler("Too many login attempts, please try again later."),
  skipSuccessfulRequests: true, // Don't count successful requests
  standardHeaders: true,
  legacyHeaders: false,
});

// Password reset (very strict)
export const resetLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 3, // Limit each IP to 3 requests per hour
  handler: jsonHandler("Too many password reset attempts, please try again later."),
  standardHeaders: true,
  legacyHeaders: false,
});

// MQTT webhook endpoints
export const mqttLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 300, // Allow high frequency from MQTT broker
  handler: jsonHandler("Too many MQTT requests."),
  standardHeaders: true,
  legacyHeaders: false,
});
