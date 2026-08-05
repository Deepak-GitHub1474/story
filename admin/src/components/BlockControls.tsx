'use client';

import { useState, useTransition } from 'react';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { setBlocked } from '@/lib/actions';

export function BlockControls({
  username,
  isBlocked,
}: {
  username: string;
  isBlocked: boolean;
}) {
  const [reason, setReason] = useState('');
  const [isPending, startTransition] = useTransition();

  if (isBlocked) {
    return (
      <Button
        variant="secondary"
        isFullWidth={false}
        isLoading={isPending}
        onClick={() =>
          startTransition(async () => {
            await setBlocked(username, false, '');
          })
        }
      >
        Unblock account
      </Button>
    );
  }

  return (
    <div className="space-y-4 rounded-[length:var(--radius-md)] border border-danger bg-surface p-5">
      <h2 className="font-bold text-danger">Block this account</h2>
      <p className="text-[length:var(--text-label)] leading-relaxed text-text-secondary">
        They cannot sign in, and their stories leave every feed. The reason is internal
        and is never shown to them.
      </p>
      <Field
        label="Reason"
        value={reason}
        onChange={(event) => setReason(event.target.value)}
        maxLength={200}
        hint="Written to the audit log."
      />
      <Button
        variant="danger"
        isFullWidth={false}
        disabled={!reason.trim()}
        isLoading={isPending}
        onClick={() =>
          startTransition(async () => {
            await setBlocked(username, true, reason.trim());
          })
        }
      >
        Block account
      </Button>
    </div>
  );
}
