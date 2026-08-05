'use client';

import { useTransition } from 'react';
import { markAllRead } from '@/lib/actions/notifications';

export function MarkAllRead() {
  const [isPending, startTransition] = useTransition();

  return (
    <button
      type="button"
      disabled={isPending}
      onClick={() => startTransition(async () => void (await markAllRead()))}
      className="text-[length:var(--text-label)] text-accent hover:underline disabled:opacity-50"
    >
      Mark all read
    </button>
  );
}
