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


