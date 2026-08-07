'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { API_BASE_URL } from '../config';
import { backendFetch, clearSession } from '../server/session';
import type { TEnvelope } from '../types';

import type { TFormState } from './state';

export async function updateProfile(
  _prev: TFormState,
  form: FormData,
): Promise<TFormState> {
  const result = await backendFetch('/users/me', {
    method: 'PATCH',
    body: {
      display_name: String(form.get('display_name') ?? '').trim(),
      bio: String(form.get('bio') ?? '').trim(),
    },
  });
  if (!result.ok) return { error: result.message, ok: null };
  revalidatePath('/profile');
  revalidatePath('/settings');
  return { error: null, ok: 'Profile updated.' };
}

export async function updateInterests(slugs: string[]) {
  await backendFetch('/users/me', { method: 'PATCH', body: { interests: slugs } });
  revalidatePath('/profile');
}

export async function setNotifications(enabled: boolean) {
  await backendFetch('/users/me', {
    method: 'PATCH',
    body: { prefs: { notify_in_app: enabled } },
  });
  revalidatePath('/settings');
}

export async function addEmail(_prev: TFormState, form: FormData): Promise<TFormState> {
  const result = await backendFetch('/users/me/email', {
    method: 'POST',
    body: { email: String(form.get('email') ?? '').trim() },
  });
  return result.ok
    ? { error: null, ok: 'We sent a code to that address.' }
    : { error: result.message, ok: null };
}

export async function verifyEmail(_prev: TFormState, form: FormData): Promise<TFormState> {
  const result = await backendFetch('/users/me/email/verify', {
    method: 'POST',
    body: { otp: String(form.get('otp') ?? '') },
  });
  if (!result.ok) return { error: result.message, ok: null };
  revalidatePath('/settings');
  return { error: null, ok: 'Email verified.' };
}

export async function changePassword(
  _prev: TFormState,
  form: FormData,
): Promise<TFormState> {
  const result = await backendFetch('/auth/password/change', {
    method: 'POST',
    body: {
      current_password: String(form.get('current_password') ?? ''),
      new_password: String(form.get('new_password') ?? ''),
    },
  });
  return result.ok
    ? { error: null, ok: 'Password changed.' }
    : { error: result.message, ok: null };
}

export async function revokeSession(familyId: string) {
  await backendFetch(`/auth/sessions/${familyId}`, { method: 'DELETE' });
  revalidatePath('/settings/sessions');
}

export async function deactivate(_prev: TFormState, form: FormData): Promise<TFormState> {
  const result = await backendFetch('/users/me/deactivate', {
    method: 'POST',
    body: { password: String(form.get('password') ?? '') },
  });
  if (!result.ok) return { error: result.message, ok: null };
  await clearSession();
  redirect('/');
}

export async function deleteAccount(
  _prev: TFormState,
  form: FormData,
): Promise<TFormState> {
  const result = await backendFetch('/users/me/delete', {
    method: 'POST',
    body: { password: String(form.get('password') ?? ''), acknowledged: true },
  });
  if (!result.ok) return { error: result.message, ok: null };
  await clearSession();
  redirect('/');
}

async function publicPost(path: string, body: unknown) {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
    cache: 'no-store',
  });
  return (await response.json()) as TEnvelope<Record<string, unknown>>;
}

export async function requestReset(_prev: TFormState, form: FormData): Promise<TFormState> {
  await publicPost('/auth/password-reset/request', {
    username: String(form.get('username') ?? '').trim().toLowerCase(),
  });
  return { error: null, ok: 'If that account can be recovered, a code is on its way.' };
}

export async function completeReset(
  _prev: TFormState,
  form: FormData,
): Promise<TFormState> {
  const verify = await publicPost('/auth/password-reset/verify', {
    username: String(form.get('username') ?? '').trim().toLowerCase(),
    otp: String(form.get('otp') ?? ''),
  });
  if (!verify.success) return { error: verify.message, ok: null };

  const complete = await publicPost('/auth/password-reset/complete', {
    reset_token: verify.data?.reset_token,
    new_password: String(form.get('new_password') ?? ''),
    acknowledged_vault_loss: true,
  });
  if (!complete.success) return { error: complete.message, ok: null };

  redirect('/signin');
}

export async function resendEmailCode(): Promise<TFormState> {
  const result = await backendFetch('/users/me/email/resend', { method: 'POST' });
  return result.ok
    ? { error: null, ok: 'Another code is on its way.' }
    : { error: result.message, ok: null };
}

export async function removeEmail(): Promise<TFormState> {
  const result = await backendFetch('/users/me/email', { method: 'DELETE' });
  if (!result.ok) return { error: result.message, ok: null };
  revalidatePath('/settings/email');
  revalidatePath('/settings');
  return { error: null, ok: 'Recovery email removed.' };
}

export async function cancelDeletion(): Promise<TFormState> {
  const result = await backendFetch('/users/me/delete/cancel', { method: 'POST' });
  if (!result.ok) return { error: result.message, ok: null };
  revalidatePath('/settings');
  revalidatePath('/settings/leaving');
  return { error: null, ok: 'Your account is staying.' };
}

export async function regenerateAvatar() {
  await backendFetch('/users/me/avatar/regenerate', { method: 'POST' });
  revalidatePath('/profile');
  revalidatePath('/settings');
}

export async function signOutEverywhere() {
  await backendFetch('/auth/signout-all', { method: 'POST' });
  await clearSession();
  redirect('/signin');
}

export async function setAvatarSeed(seed: string) {
  const result = await backendFetch('/users/me', {
    method: 'PATCH',
    body: { avatar_seed: seed },
  });
  if (!result.ok) return { error: result.message };
  revalidatePath('/profile');
  revalidatePath('/settings');
  revalidatePath('/settings/avatar');
  return { error: null };
}

export async function setOnlineStatus(visible: boolean) {
  await backendFetch('/users/me', {
    method: 'PATCH',
    body: { prefs: { show_online_status: visible } },
  });
  revalidatePath('/settings');
}
