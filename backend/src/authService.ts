import jwt from "jsonwebtoken";
import bcrypt from "bcrypt";
import crypto from "crypto";
import { config } from "./config";

export interface JwtPayload {
  userId: number;
  email: string;
}

export const generateToken = (userId: number, email: string): string => {
  const options: jwt.SignOptions = {
    expiresIn: config.jwt.expiresIn as jwt.SignOptions["expiresIn"],
  };
  return jwt.sign({ userId, email }, config.jwt.secret, options);
};

export const verifyToken = (token: string): JwtPayload => {
  return jwt.verify(token, config.jwt.secret) as JwtPayload;
};

export const hashPassword = async (password: string): Promise<string> => {
  return bcrypt.hash(password, config.bcrypt.rounds);
};

export const verifyPassword = async (
  password: string,
  hash: string
): Promise<boolean> => {
  return bcrypt.compare(password, hash);
};

export const generateResetToken = (): string => {
  // Generate 6-digit random code
  return Math.floor(100000 + Math.random() * 900000).toString();
};

export const verifyGoogleToken = async (accessToken: string): Promise<{ email: string; id: string } | null> => {
  try {
    const response = await fetch(`https://www.googleapis.com/oauth2/v3/userinfo?access_token=${accessToken}`);
    if (!response.ok) return null;
    const data = await response.json();
    if (!data.email) return null;
    return { email: data.email, id: data.sub };
  } catch {
    return null;
  }
};

export const verifyFacebookToken = async (accessToken: string): Promise<{ email: string; id: string } | null> => {
  try {
    const response = await fetch(`https://graph.facebook.com/me?fields=id,email&access_token=${accessToken}`);
    if (!response.ok) return null;
    const data = await response.json();
    if (!data.email) return null;
    return { email: data.email, id: data.id };
  } catch {
    return null;
  }
};
