'use server';

import { backendFetch } from '../server/session';

export async function polishText(text: string, instruction: string) {
  const result = await backendFetch<{ text: string }>('/ai/polish', {
    method: 'POST',
    body: { text, instruction },
  });

  return result.ok
    ? { error: null, text: result.value.text }
    : { error: result.message, text: null };
}

export async function draftStory(subject: string, brief: string) {
  const result = await backendFetch<{ title: string; body: string }>('/ai/draft', {
    method: 'POST',
    body: { subject, brief },
  });

  return result.ok
    ? { error: null, written: result.value }
    : { error: result.message, written: null };
}
