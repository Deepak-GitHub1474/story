export type TEnvelope<T> = { success: boolean; message: string; data: T | null };

export type TResult<T> =
  | { ok: true; value: T }
  | { ok: false; code: string; message: string; status: number };

export type TStaff = {
  user_id: string;
  username: string;
  display_name: string;
  role: string;
};

export type TReport = {
  report_id: string;
  reason: string;
  note: string | null;
  state: string;
  created_at: string;
  target: {
    kind: string;
    id: string;
    title?: string | null;
    excerpt: string;
    author: string | null;
  };
};

export type TAdminUser = {
  user_id: string;
  username: string;
  display_name: string;
  avatar_seed: string;
  role: string;
  status: string;
  blocked: boolean;
  blocked_reason: string | null;
  counts: Record<string, number>;
  created_at: string;
  last_login_at: string | null;
};

export type TAuditEntry = {
  entry_id: string;
  action: string;
  actor: { username?: string; role?: string };
  target: { kind?: string; id?: string };
  outcome: string;
  details: Record<string, unknown>;
  occurred_at: string;
};

export type TStats = {
  users: number;
  blocked_users: number;
  stories: number;
  comments: number;
  open_reports: number;
  communities: number;
};

export type TTokens = { access_token: string; refresh_token: string };
