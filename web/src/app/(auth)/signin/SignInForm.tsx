'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useActionState, useEffect, useState } from 'react';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { signIn } from '@/lib/actions/auth';
import { EMPTY_FORM } from '@/lib/actions/state';
import { bootstrapChat } from '@/lib/chat/useIdentity';

export function SignInForm() {
  const router = useRouter();
  const [state, action, isPending] = useActionState(signIn, EMPTY_FORM);
  const [showPassword, setShowPassword] = useState(false);
  const [password, setPassword] = useState('');

  useEffect(() => {
    if (!state.userId) return;
    void bootstrapChat(state.userId, password).then(() => router.push('/feed'));
  }, [state.userId, password, router]);

  return (
    <form action={action} className="flex flex-col gap-6">
      <header>
        <h1 className="text-[length:var(--text-title)] font-semibold">Welcome back</h1>
        <p className="mt-2 text-text-secondary">
          Your username and password are the only things we know about you.
        </p>
      </header>

      <Field
        label="Username"
        name="username"
        autoComplete="username"
        autoCapitalize="none"
        spellCheck={false}
        required
        error={state.field === 'username' ? state.error : null}
      />

      <Field
        label="Password"
        name="password"
        type={showPassword ? 'text' : 'password'}
        autoComplete="current-password"
        value={password}
        onChange={(event) => setPassword(event.target.value)}
        required
        error={state.field === 'password' ? state.error : null}
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

      {state.error && !state.field ? (
        <p
          role="alert"
          className="rounded-[length:var(--radius-md)] border border-danger bg-surface px-4 py-3 text-[length:var(--text-label)] text-danger"
        >
          {state.error}
        </p>
      ) : null}

      <div className="flex justify-end">
        <Link
          href="/forgot-password"
          className="text-[length:var(--text-label)] text-accent hover:underline"
        >
          Forgot password?
        </Link>
      </div>

      <Button type="submit" isLoading={isPending}>
        Sign in
      </Button>

      <p className="text-center text-[length:var(--text-label)] text-text-secondary">
        No account?{' '}
        <Link href="/signup" className="text-accent hover:underline">
          Create one
        </Link>
      </p>
    </form>
  );
}
