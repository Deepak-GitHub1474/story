'use server';

import { revalidatePath } from 'next/cache';
import { backendFetch } from '../server/session';
import { EMPTY, type TFormState } from './account';

export { EMPTY };
export type { TFormState };

export async function openPasscodeRelease(
  _prev: TFormState,
  form: FormData,
): Promise<TFormState> {
  const reason = String(form.get('reason') ?? '').trim();
  const result = await backendFetch('/tickets', {
    method: 'POST',
    body: { type: 'passcode_release', reason },
  });
  if (!result.ok) return { error: result.message, ok: null };
  revalidatePath('/vault/recovery');
  return { error: null, ok: 'Request opened. A person will look at it.' };
}
