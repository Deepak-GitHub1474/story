import { redirect } from 'next/navigation';
import { backendFetch } from './session';
import type { TStaff } from '../types';

const STAFF_ROLES = ['moderator', 'admin', 'super_admin'];

export async function currentStaff(): Promise<TStaff | null> {
  const result = await backendFetch<{ user: TStaff }>('/auth/me');
  if (!result.ok) return null;
  return STAFF_ROLES.includes(result.value.user.role) ? result.value.user : null;
}

export async function requireStaff(): Promise<TStaff> {
  const staff = await currentStaff();
  if (!staff) redirect('/signin');
  return staff;
}

export async function requireAdmin(): Promise<TStaff> {
  const staff = await requireStaff();
  if (staff.role === 'moderator') redirect('/queue');
  return staff;
}
