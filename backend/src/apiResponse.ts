import { Request, Response, NextFunction } from "express";

export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: any;
  };
  timestamp: string;
}

export class ApiError extends Error {
  constructor(
    public statusCode: number,
    public errorCode: string,
    message: string,
    public details?: any
  ) {
    super(message);
    this.name = "ApiError";
  }
}

export const errorHandler = (
  err: Error | ApiError,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const timestamp = new Date().toISOString();

  if (err instanceof ApiError) {
    const response: ApiResponse = {
      success: false,
      error: {
        code: err.errorCode,
        message: err.message,
        details: err.details,
      },
      timestamp,
    };
    return res.status(err.statusCode).json(response);
  }

  // Handle unexpected errors
  const response: ApiResponse = {
    success: false,
    error: {
      code: "INTERNAL_SERVER_ERROR",
      message: "An unexpected error occurred",
      details: process.env.NODE_ENV === "development" ? err.message : undefined,
    },
    timestamp,
  };

  res.status(500).json(response);
};

export const successResponse = <T>(data: T, statusCode: number = 200) => ({
  success: true,
  data,
  timestamp: new Date().toISOString(),
});
