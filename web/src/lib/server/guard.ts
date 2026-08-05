import { redirect } from 'next/navigation';
import { backendFetch } from './session';
import type { TMe } from '../types';

export async function currentUser(): Promise<TMe | null> {
  const result = await backendFetch<{ user: TMe }>('/auth/me');
  return result.ok ? result.value.user : null;
}

export async function requireUser(): Promise<TMe> {
  const user = await currentUser();
  if (!user) redirect('/signin');
  return user;
}

export async function redirectIfSignedIn() {
  const user = await currentUser();
  if (user) redirect('/feed');
}
