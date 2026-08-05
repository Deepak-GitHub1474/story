'use server';

import { redirect } from 'next/navigation';
import { API_BASE_URL } from '../config';
import { clearSession, saveSession, backendFetch } from '../server/session';
import type { TEnvelope, TTokens } from '../types';
import type { TMe } from '../types';

export type TFormState = { error: string | null; field: string | null };

export const EMPTY_FORM: TFormState = { error: null, field: null };

type AuthPayload = { user: TMe; tokens: TTokens };

async function callPublic(path: string, body: unknown): Promise<TEnvelope<AuthPayload>> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
    cache: 'no-store',
  });
  return (await response.json()) as TEnvelope<AuthPayload>;
}

function failure(envelope: TEnvelope<unknown>): TFormState {
  const data = envelope.data as { field?: string } | null;
  return { error: envelope.message, field: data?.field ?? null };
}

export async function signIn(
  _prev: TFormState,
  form: FormData,
): Promise<TFormState> {
  const envelope = await callPublic('/auth/signin', {
    username: String(form.get('username') ?? '').trim().toLowerCase(),
    password: String(form.get('password') ?? ''),
    device: { platform: 'web', app_version: '0.1.0' },
  });

  if (!envelope.success || !envelope.data) return failure(envelope);

  await saveSession(envelope.data.tokens);
  redirect('/feed');
}

export async function signUp(
  _prev: TFormState,
  form: FormData,
): Promise<TFormState> {
  const referral = String(form.get('referral_code') ?? '').trim().toUpperCase();

  const envelope = await callPublic('/auth/signup', {
    username: String(form.get('username') ?? '').trim().toLowerCase(),
    password: String(form.get('password') ?? ''),
    tnc_accepted: form.get('tnc_accepted') === 'on',
    ...(referral ? { referral_code: referral } : {}),
  });

  if (!envelope.success || !envelope.data) return failure(envelope);

  await saveSession(envelope.data.tokens);
  redirect('/onboarding');
}

export async function signOut() {
  await backendFetch('/auth/signout', { method: 'POST' });
  await clearSession();
  redirect('/');
}

export async function checkUsername(username: string): Promise<boolean | null> {
  const response = await fetch(`${API_BASE_URL}/auth/username-available`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ username }),
    cache: 'no-store',
  });
  const envelope = (await response.json()) as TEnvelope<{ available: boolean }>;
  return envelope.success ? (envelope.data?.available ?? null) : null;
}
