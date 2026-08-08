'use client';

import { useTransition } from 'react';
import { signOut } from '@/lib/actions/auth';

export function SignOutButton() {
  const [isPending, startTransition] = useTransition();

  return (
    <button
      type="button"
      disabled={isPending}
      onClick={() => {
        if (confirm('Sign out? You will need your username and password to come back.')) {
          startTransition(async () => void (await signOut()));
        }
      }}
      className="text-[length:var(--text-label)] font-medium text-danger hover:underline disabled:opacity-50"
    >
      Sign out
    </button>
  );
}
