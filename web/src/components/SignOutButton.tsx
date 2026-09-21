'use client';

import { useState, useTransition } from 'react';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { signOut } from '@/lib/actions/auth';

export function SignOutButton() {
  const [isAsking, setAsking] = useState(false);
  const [isPending, startTransition] = useTransition();

  return (
    <>
      <button
        type="button"
        disabled={isPending}
        onClick={() => setAsking(true)}
        className="text-[length:var(--text-label)] font-medium text-danger hover:underline disabled:opacity-50"
      >
        Sign out
      </button>

      <ConfirmDialog
        isOpen={isAsking}
        title="Sign out?"
        body="You will need your username and password to come back. There is no email on file to recover with unless you set one."
        confirmLabel="Sign out"
        isDanger
        isPending={isPending}
        onCancel={() => setAsking(false)}
        onConfirm={() => {
          setAsking(false);
          startTransition(async () => void (await signOut()));
        }}
      />
    </>
  );
}
