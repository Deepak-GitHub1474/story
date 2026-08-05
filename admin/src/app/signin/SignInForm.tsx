'use client';

import { useActionState } from 'react';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { EMPTY, signIn } from '@/lib/actions';

export function SignInForm() {
  const [state, action, isPending] = useActionState(signIn, EMPTY);

  return (
    <form action={action} className="flex flex-col gap-6">
      <Field label="Username" name="username" autoComplete="username" required />
      <Field
        label="Password"
        name="password"
        type="password"
        autoComplete="current-password"
        required
      />
      {state.error ? (
        <p
          role="alert"
          className="rounded-[length:var(--radius-md)] border border-danger bg-surface px-4 py-3 text-[length:var(--text-label)] text-danger"
        >
          {state.error}
        </p>
      ) : null}
      <Button type="submit" isLoading={isPending}>
        Sign in
      </Button>
    </form>
  );
}
