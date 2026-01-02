export interface User {
  id: number;
  email: string;
  password_hash: string | null;
  oauth_provider?: string | null;
  oauth_id?: string | null;
  reset_token?: string | null;
  reset_token_expires?: Date | null;
  created_at: Date;
}

export interface AuthRequest {
  email: string;
  password: string;
}

export interface AuthResponse {
  token: string;
  user: {
    id: number;
    email: string;
  };
}

// Device types
export interface Device {
  device_id: string;
  user_id: number;
  created_at: Date;
}

export interface DeviceResponse {
  deviceId: string;
  lastTelemetry: TelemetryData | null;
  status: string | null;
  statusReportedAt: string | null;
}

export interface TelemetryData {
  airTemperature: number;
  airHumidity: number;
  soilTemperature: number;
  soilMoisture: number;
  lightLevel: number;
  recordedAt: string;
}

export interface TelemetryResponse {
  deviceId: string;
  airTemperature: number;
  airHumidity: number;
  soilTemperature: number;
  soilMoisture: number;
  lightLevel: number;
  recordedAt: string;
}
