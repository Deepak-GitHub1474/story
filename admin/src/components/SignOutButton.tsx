'use client';

import { useTransition } from 'react';
import { signOut } from '@/lib/actions';

export function SignOutButton() {
  const [isPending, startTransition] = useTransition();

  return (
    <button
      type="button"
      disabled={isPending}
      onClick={() => startTransition(async () => void (await signOut()))}
      className="text-[length:var(--text-label)] text-text-muted transition-colors hover:text-text-primary disabled:opacity-50"
    >
      Sign out
    </button>
  );
}
