import { cookies } from 'next/headers';
import { API_BASE_URL } from '../config';
import type { TEnvelope, TResult } from '../types';

export const ACCESS_COOKIE = 'story_access';
export const REFRESH_COOKIE = 'story_refresh';

const ACCESS_MAX_AGE = 60 * 30;
const REFRESH_MAX_AGE = 60 * 60 * 24 * 30;

export type TTokens = { access_token: string; refresh_token: string };

export async function saveSession(tokens: TTokens) {
  const jar = await cookies();
  const secure = process.env.NODE_ENV === 'production';

  jar.set(ACCESS_COOKIE, tokens.access_token, {
    httpOnly: true,
    sameSite: 'lax',
    secure,
    path: '/',
    maxAge: ACCESS_MAX_AGE,
  });
  jar.set(REFRESH_COOKIE, tokens.refresh_token, {
    httpOnly: true,
    sameSite: 'lax',
    secure,
    path: '/',
    maxAge: REFRESH_MAX_AGE,
  });
}

export async function clearSession() {
  const jar = await cookies();
  jar.delete(ACCESS_COOKIE);
  jar.delete(REFRESH_COOKIE);
}

export async function accessToken(): Promise<string | null> {
  return (await cookies()).get(ACCESS_COOKIE)?.value ?? null;
}

async function refreshTokens(): Promise<string | null> {
  const jar = await cookies();
  const refresh = jar.get(REFRESH_COOKIE)?.value;
  if (!refresh) return null;

  const response = await fetch(`${API_BASE_URL}/auth/refresh`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ refresh_token: refresh }),
    cache: 'no-store',
  });

  const envelope = (await response.json().catch(() => null)) as TEnvelope<{
    tokens: TTokens;
  }> | null;

  if (!response.ok || !envelope?.success || !envelope.data) {
    await clearSession();
    return null;
  }

  await saveSession(envelope.data.tokens);
  return envelope.data.tokens.access_token;
}

export async function backendFetch<T>(
  path: string,
  init: { method?: string; body?: unknown } = {},
  retried = false,
): Promise<TResult<T>> {
  const token = await accessToken();

  let response: Response;
  try {
    response = await fetch(`${API_BASE_URL}${path}`, {
      method: init.method ?? 'GET',
      headers: {
        'content-type': 'application/json',
        ...(token ? { authorization: `Bearer ${token}` } : {}),
      },
      body: init.body === undefined ? undefined : JSON.stringify(init.body),
      cache: 'no-store',
    });
  } catch {
    return {
      ok: false,
      code: 'NETWORK_UNAVAILABLE',
      message: 'Could not reach the server.',
      status: 0,
    };
  }

  const envelope = (await response.json().catch(() => null)) as TEnvelope<T> | null;

  if (envelope === null) {
    return {
      ok: false,
      code: 'MALFORMED_RESPONSE',
      message: 'The server returned something unexpected.',
      status: response.status,
    };
  }

  if (response.ok && envelope.success) {
    return { ok: true, value: envelope.data as T };
  }

  const data = envelope.data as { code?: string } | null;
  const code = data?.code ?? 'INTERNAL_ERROR';

  if (response.status === 401 && code === 'TOKEN_EXPIRED' && !retried) {
    const fresh = await refreshTokens();
    if (fresh) return backendFetch<T>(path, init, true);
  }

  return { ok: false, code, message: envelope.message, status: response.status };
}
