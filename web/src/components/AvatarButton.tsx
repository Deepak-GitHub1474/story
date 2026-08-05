'use client';

import { useTransition } from 'react';
import { regenerateAvatar } from '@/lib/actions/account';

export function AvatarButton() {
  const [isPending, startTransition] = useTransition();

  return (
    <button
      type="button"
      disabled={isPending}
      onClick={() => startTransition(async () => void (await regenerateAvatar()))}
      className="text-[length:var(--text-label)] font-semibold text-accent transition-opacity disabled:opacity-50"
    >
      {isPending ? 'Shuffling…' : 'Shuffle'}
    </button>
  );
}
