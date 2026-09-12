'use client';

import { useActionState, useState } from 'react';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { signIn } from '@/lib/actions';
import { EMPTY } from '@/lib/formState';

export function SignInForm() {
  const [state, action, isPending] = useActionState(signIn, EMPTY);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);

  return (
    <form action={action} className="flex flex-col gap-6">
      <Field
        label="Username"
        name="username"
        autoComplete="username"
        autoCapitalize="none"
        spellCheck={false}
        value={username}
        onChange={(event) => setUsername(event.target.value)}
        required
      />

      <Field
        label="Password"
        name="password"
        type={showPassword ? 'text' : 'password'}
        autoComplete="current-password"
        value={password}
        onChange={(event) => setPassword(event.target.value)}
        required
        suffix={
          <button
            type="button"
            onClick={() => setShowPassword((value) => !value)}
            className="text-[length:var(--text-caption)] text-text-muted hover:text-text-secondary"
          >
            {showPassword ? 'Hide' : 'Show'}
          </button>
        }
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
