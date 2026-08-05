'use client';

import { useActionState, useState } from 'react';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { PasswordStrength } from '@/components/ui/PasswordStrength';
import { changePassword } from '@/lib/actions/account';
import { EMPTY } from '@/lib/actions/state';

export function ChangePasswordForm() {
  const [state, action, isPending] = useActionState(changePassword, EMPTY);
  const [next, setNext] = useState('');

  return (
    <form action={action} className="mx-auto flex max-w-lg flex-col gap-6">
      <h1 className="text-[length:var(--text-title)] font-semibold">Change password</h1>

      <p className="rounded-[length:var(--radius-md)] border border-border bg-surface px-4 py-3 leading-relaxed text-text-secondary">
        Changing your password keeps you signed in and keeps your account intact. It is
        not the same as resetting a forgotten password.
      </p>

      <Field
        label="Current password"
        name="current_password"
        type="password"
        autoComplete="current-password"
        required
      />

      <div className="flex flex-col gap-2">
        <Field
          label="New password"
          name="new_password"
          type="password"
          autoComplete="new-password"
          value={next}
          onChange={(event) => setNext(event.target.value)}
          required
          hint="At least 10 characters."
        />
        <PasswordStrength password={next} />
      </div>

      {state.error ? (
        <p role="alert" className="text-[length:var(--text-label)] text-danger">
          {state.error}
        </p>
      ) : null}
      {state.ok ? (
        <p role="status" className="text-[length:var(--text-label)] text-success">
          {state.ok}
        </p>
      ) : null}

      <Button type="submit" isLoading={isPending} disabled={next.length < 10}>
        Change password
      </Button>
    </form>
  );
}
