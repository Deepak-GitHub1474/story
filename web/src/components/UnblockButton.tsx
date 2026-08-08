'use client';

import { useTransition } from 'react';
import { unblockUser } from '@/lib/actions/stories';

export function UnblockButton({ username }: { username: string }) {
  const [isPending, startTransition] = useTransition();

  return (
    <button
      type="button"
      disabled={isPending}
      onClick={() => startTransition(async () => void (await unblockUser(username)))}
      className="text-[length:var(--text-label)] font-medium text-accent hover:underline disabled:opacity-50"
    >
      Unblock
    </button>
  );
}
