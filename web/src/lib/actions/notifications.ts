'use server';

import { revalidatePath } from 'next/cache';
import { backendFetch } from '../server/session';

export async function markAllRead() {
  await backendFetch('/notifications/read-all', { method: 'POST' });
  revalidatePath('/activity');
}

export async function markRead(notificationId: string) {
  await backendFetch(`/notifications/${notificationId}/read`, { method: 'POST' });
  revalidatePath('/activity');
}
