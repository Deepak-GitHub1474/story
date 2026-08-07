'use server';

import { backendFetch } from '../server/session';
import type { TVaultItem, TVaultKeys, TVaultPasscode } from '../types';

export async function loadKeys() {
  const result = await backendFetch<TVaultKeys>('/users/me/keys');
  return result.ok ? result.value : null;
}

export async function loadPasscodes() {
  const result = await backendFetch<{ items: TVaultPasscode[] }>('/vault/passcodes');
  return result.ok ? result.value.items : [];
}

export async function loadItems(passcodeId: string) {
  const result = await backendFetch<{ items: TVaultItem[] }>(
    `/vault/items?passcode_id=${encodeURIComponent(passcodeId)}`,
  );
  return result.ok ? result.value.items : [];
}

export async function loadItem(itemId: string) {
  const result = await backendFetch<{ item: TVaultItem }>(`/vault/items/${itemId}`);
  return result.ok ? result.value.item : null;
}

export async function findSealed(labelHash: string) {
  const result = await backendFetch<{ item: TVaultItem }>('/vault/search', {
    method: 'POST',
    body: { label_hash: labelHash },
  });
  return result.ok ? result.value.item : null;
}

export async function downloadUrl(itemId: string) {
  const result = await backendFetch<{ url: string }>(`/vault/items/${itemId}/download`);
  return result.ok ? result.value.url : null;
}
