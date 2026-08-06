'use client';

import Link from 'next/link';
import { useActionState, useEffect, useState } from 'react';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { PasswordStrength } from '@/components/ui/PasswordStrength';
import { useRouter } from 'next/navigation';
import { checkUsername, signUp } from '@/lib/actions/auth';
import { EMPTY_FORM } from '@/lib/actions/state';
import { bootstrapChat } from '@/lib/chat/useIdentity';

const USERNAME_PATTERN = /^[a-z0-9](?:[a-z0-9_-]*[a-z0-9])?$/;
const USERNAME_MIN = 2;
const USERNAME_MAX = 30;

export function SignUpForm() {
  const [state, action, isPending] = useActionState(signUp, EMPTY_FORM);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [accepted, setAccepted] = useState(false);
  const [available, setAvailable] = useState<boolean | null>(null);
  const router = useRouter();

  useEffect(() => {
    if (!state.userId) return;
    void bootstrapChat(state.userId, password).then(() => router.push('/onboarding'));
  }, [state.userId, password, router]);

  const isWellFormed =
    username.length >= USERNAME_MIN &&
    username.length <= USERNAME_MAX &&
    USERNAME_PATTERN.test(username) &&
    !username.includes('--');

  useEffect(() => {
    if (!isWellFormed) {
      setAvailable(null);
      return;
    }

    let cancelled = false;
    const timer = setTimeout(async () => {
      const result = await checkUsername(username);
      if (!cancelled) setAvailable(result);
    }, 400);

    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [username, isWellFormed]);

  const canSubmit =
    isWellFormed &&
    password.length >= 10 &&
    accepted &&
    available !== false;

  return (
    <form action={action} className="flex flex-col gap-6">
      <header>
        <h1 className="text-[length:var(--text-title)] font-semibold">
          Create your account
        </h1>
        <p className="mt-2 text-text-secondary">
          Pick a name nobody can trace back to you. No email, no phone.
        </p>
      </header>

      <Field
        label="Username"
        name="username"
        value={username}
        onChange={(event) =>
          setUsername(event.target.value.toLowerCase().replace(/[^a-z0-9_]/g, ''))
        }
        maxLength={20}
        autoCapitalize="none"
        spellCheck={false}
        placeholder="quiet_fox"
        required
        error={
          available === false
            ? 'That username is already taken.'
            : state.field === 'username'
              ? state.error
              : null
        }
        hint={available === true ? 'Available.' : null}
      />

      <div className="flex flex-col gap-2">
        <Field
          label="Password"
          name="password"
          type="password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          autoComplete="new-password"
          required
          error={state.field === 'password' ? state.error : null}
          hint="At least 10 characters. Never recoverable, so keep it safe."
        />
        <PasswordStrength password={password} />
      </div>

      <Field
        label="Referral code (optional)"
        name="referral_code"
        maxLength={6}
        placeholder="ABC123"
        className="uppercase"
        error={state.field === 'referral_code' ? state.error : null}
      />

      <label className="flex cursor-pointer items-start gap-3">
        <input
          type="checkbox"
          name="tnc_accepted"
          checked={accepted}
          onChange={(event) => setAccepted(event.target.checked)}
          className="mt-0.5 size-[22px] shrink-0 accent-[var(--c-accent)]"
        />
        <span className="text-[length:var(--text-label)] leading-relaxed text-text-secondary">
          I accept the terms and understand that a forgotten password cannot be
          recovered without an email on the account.
        </span>
      </label>

      {state.error && !state.field ? (
        <p
          role="alert"
          className="rounded-[length:var(--radius-md)] border border-danger bg-surface px-4 py-3 text-[length:var(--text-label)] text-danger"
        >
          {state.error}
        </p>
      ) : null}

      <Button type="submit" isLoading={isPending} disabled={!canSubmit}>
        Create account
      </Button>

      <p className="text-center text-[length:var(--text-label)] text-text-secondary">
        Already have one?{' '}
        <Link href="/signin" className="text-accent hover:underline">
          Sign in
        </Link>
      </p>
    </form>
  );
}
