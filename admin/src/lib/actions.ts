'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { API_BASE_URL } from './config';
import { backendFetch, clearSession, saveSession } from './server/session';
import type { TEnvelope, TStaff, TTokens } from './types';

export type TFormState = { error: string | null };
export const EMPTY: TFormState = { error: null };

const STAFF_ROLES = ['moderator', 'admin', 'super_admin'];

export async function signIn(_prev: TFormState, form: FormData): Promise<TFormState> {
  const response = await fetch(`${API_BASE_URL}/auth/signin`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      username: String(form.get('username') ?? '').trim().toLowerCase(),
      password: String(form.get('password') ?? ''),
      device: { platform: 'web', app_version: 'admin-0.1.0' },
    }),
    cache: 'no-store',
  });

  const envelope = (await response.json()) as TEnvelope<{
    user: TStaff;
    tokens: TTokens;
  }>;

  if (!envelope.success || !envelope.data) {
    return { error: envelope.message };
  }

  if (!STAFF_ROLES.includes(envelope.data.user.role)) {
    return { error: 'This account has no access here.' };
  }

  await saveSession(envelope.data.tokens);
  redirect('/queue');
}

export async function signOut() {
  await backendFetch('/auth/signout', { method: 'POST' });
  await clearSession();
  redirect('/signin');
}

export async function resolveReport(reportId: string, outcome: 'actioned' | 'dismissed') {
  await backendFetch(`/admin/reports/${reportId}/resolve`, {
    method: 'POST',
    body: { outcome },
  });
  revalidatePath('/queue');
}

export async function setBlocked(username: string, blocked: boolean, reason: string) {
  await backendFetch(
    `/admin/users/${username}/${blocked ? 'block' : 'unblock'}`,
    blocked ? { method: 'POST', body: { reason } } : { method: 'POST' },
  );
  revalidatePath(`/users/${username}`);
  revalidatePath('/users');
}

export async function listPasscodes(username: string) {
  const result = await backendFetch<{ items: unknown[] }>(
    `/admin/vault/${username}/passcodes`,
  );
  return result.ok
    ? { error: null, items: result.value.items }
    : { error: result.message, items: [] };
}

export async function releaseEscrow(
  username: string,
  ticketId: string,
  justification: string,
) {
  const result = await backendFetch(`/admin/vault/${username}/release`, {
    method: 'POST',
    body: { ticket_id: ticketId, justification },
  });
  return result.ok ? { error: null } : { error: result.message };
}
