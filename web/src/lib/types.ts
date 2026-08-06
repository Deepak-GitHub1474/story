export type TEnvelope<T> = {
  success: boolean;
  message: string;
  data: T | null;
};

export type TStoryAuthor = {
  display_name: string;
  avatar_seed: string;
  username: string;
};

export type TPublicStory = {
  slug: string;
  title: string | null;
  body: string;
  excerpt: string;
  author: TStoryAuthor;
  community: { slug: string; name: string } | null;
  counts: { likes?: number; comments?: number };
  reading_minutes: number;
  published_at: string | null;
};

export type TResult<T> =
  | { ok: true; value: T }
  | { ok: false; code: string; message: string; status: number };

export type TMe = {
  user_id: string;
  username: string;
  display_name: string;
  avatar_seed: string;
  role: string;
  status: string;
  blocked: boolean;
  referral_code: string;
  referred_by: string | null;
  bio: string | null;
  interests: string[];
  counts: Record<string, number>;
  prefs: Record<string, unknown>;
  email_masked: string | null;
  email_verified: boolean;
  created_at: string;
};

export type TSharedStory = {
  story_id: string;
  title: string | null;
  excerpt: string;
  slug: string | null;
  author: TStoryAuthor & { user_id: string | null };
};

export type TStory = {
  story_id: string;
  author: TStoryAuthor & { user_id: string | null };
  title: string | null;
  excerpt: string;
  body?: string;
  visibility: string;
  slug: string | null;
  community: { slug: string; name: string } | null;
  counts: { likes: number; comments: number };
  reading_minutes: number;
  is_liked: boolean;
  published_at: string | null;
  created_at: string;
  shared?: TSharedStory | null;
};

export type TPage<T> = { items: T[]; next_cursor: string | null; has_more: boolean };

export type TComment = {
  comment_id: string;
  story_id: string;
  parent_id: string | null;
  author: TStoryAuthor & { user_id: string | null };
  body: string;
  counts: { likes: number; replies: number };
  is_liked: boolean;
  created_at: string;
  edited_at: string | null;
  replies?: TComment[];
};

export type TCommunity = {
  slug: string;
  name: string;
  description: string;
  category_id: string;
  counts: { members: number; stories: number };
  is_member: boolean;
};

export type TNotification = {
  notification_id: string;
  kind: string;
  actor: TStoryAuthor & { user_id: string | null };
  target: { kind: string; id: string } | null;
  body: string;
  is_read: boolean;
  created_at: string;
};

export type TTokens = { access_token: string; refresh_token: string };

export type TVaultKeys = {
  salt_pw: string;
  wrapped_umk: string;
  kdf: Record<string, number | string>;
};

export type TVaultPasscode = {
  passcode_id: string;
  label: string;
  scope: string;
  salt_pc: string;
  kdf: Record<string, number | string>;
};

export type TVaultItem = {
  item_id: string;
  kind: string;
  size_bytes: number;
  encrypted_metadata: string;
  visibility: string;
  status: string;
  created_at: string;
  wrapped_dek?: string;
  salt_item?: string;
};
