import { API_BASE_URL } from './config';
import type { TEnvelope, TResult } from './types';

type Options = {
  method?: string;
  body?: unknown;
  revalidate?: number;
  token?: string;
};

export async function apiCall<T>(
  path: string,
  { method = 'GET', body, revalidate, token }: Options = {},
): Promise<TResult<T>> {
  let response: Response;

  try {
    response = await fetch(`${API_BASE_URL}${path}`, {
      method,
      headers: {
        'content-type': 'application/json',
        ...(token ? { authorization: `Bearer ${token}` } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      ...(revalidate === undefined
        ? { cache: 'no-store' as const }
        : { next: { revalidate } }),
    });
  } catch {
    return {
      ok: false,
      code: 'NETWORK_UNAVAILABLE',
      message: 'Could not reach the server.',
      status: 0,
    };
  }

  let envelope: TEnvelope<T>;
  try {
    envelope = (await response.json()) as TEnvelope<T>;
  } catch {
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
  return {
    ok: false,
    code: data?.code ?? 'INTERNAL_ERROR',
    message: envelope.message || 'Something went wrong.',
    status: response.status,
  };
}
