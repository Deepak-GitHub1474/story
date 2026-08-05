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
