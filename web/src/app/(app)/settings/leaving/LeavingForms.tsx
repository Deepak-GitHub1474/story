'use client';

import { useActionState, useState } from 'react';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { deactivate, deleteAccount } from '@/lib/actions/account';
import { EMPTY } from '@/lib/actions/state';

const CONFIRM_WORD = 'DELETE';

export function LeavingForms() {
  const [deactivateState, deactivateAction, isDeactivating] = useActionState(
    deactivate,
    EMPTY,
  );
  const [deleteState, deleteAction, isDeleting] = useActionState(deleteAccount, EMPTY);
  const [confirm, setConfirm] = useState('');

  return (
    <div className="mx-auto max-w-lg space-y-10">
      <h1 className="text-[length:var(--text-title)] font-medium">Leaving</h1>

      <form
        action={deactivateAction}
        className="rounded-[length:var(--radius-md)] border border-border bg-surface p-6"
      >
        <h2 className="text-[length:var(--text-heading)] font-medium">Deactivate</h2>
        <ul className="mt-3 space-y-1.5 text-[length:var(--text-label)] leading-relaxed text-text-secondary">
          <li>Your stories stop appearing to anyone.</li>
          <li>Your profile becomes unreachable.</li>
          <li>Signing in restores all of it, exactly as it was.</li>
        </ul>
        <div className="mt-5 space-y-4">
          <Field
            label="Password"
            name="password"
            type="password"
            required
            error={deactivateState.error}
          />
          <Button type="submit" variant="secondary" isLoading={isDeactivating}>
            Deactivate account
          </Button>
        </div>
      </form>

      <form
        action={deleteAction}
        className="rounded-[length:var(--radius-md)] border border-danger bg-surface p-6"
      >
        <h2 className="text-[length:var(--text-heading)] font-medium text-danger">Delete</h2>
        <ul className="mt-3 space-y-1.5 text-[length:var(--text-label)] leading-relaxed text-text-secondary">
          <li>Every story, draft and comment is removed.</li>
          <li>Your username is released for anyone to take.</li>
          <li>You have 14 days to cancel. After that, nothing brings it back.</li>
        </ul>
        <div className="mt-5 space-y-4">
          <Field
            label="Password"
            name="password"
            type="password"
            required
            error={deleteState.error}
          />
          <Field
            label={`Type ${CONFIRM_WORD} to confirm`}
            value={confirm}
            onChange={(event) => setConfirm(event.target.value)}
          />
          <Button
            type="submit"
            variant="danger"
            isLoading={isDeleting}
            disabled={confirm.trim() !== CONFIRM_WORD}
            onClick={(event) => {
              if (!confirm.trim().length || !window.confirm('Delete your account?')) {
                event.preventDefault();
              }
            }}
          >
            Delete account
          </Button>
        </div>
      </form>
    </div>
  );
}
