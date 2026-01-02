import { express, Pool } from "pg";
import { ApiError } from "./apiResponse";

export const checkDeviceAccess = async (
  pool: Pool,
  deviceId: string,
  userId: number
): Promise<boolean> => {
  const result = await pool.query(
    "SELECT user_id FROM devices WHERE device_id = $1",
    [deviceId]
  );
  if (result.rows.length === 0) return false;
  const ownerId = result.rows[0].user_id;
  return ownerId === userId || ownerId === 1; // System user (1) allows access
};

export const assertDeviceAccess = async (
  pool: Pool,
  deviceId: string,
  userId: number
) => {
  const hasAccess = await checkDeviceAccess(pool, deviceId, userId);
  if (!hasAccess) {
    throw new ApiError(403, "FORBIDDEN", "Access denied to this device");
  }
};

export const validateLimit = (limit?: string): number => {
  const parsed = parseInt(limit ?? "100", 10) || 100;
  return Math.min(Math.max(parsed, 1), 1000);
};
