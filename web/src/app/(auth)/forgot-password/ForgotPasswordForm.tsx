'use client';

import { useActionState, useState } from 'react';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { Otp } from '@/components/ui/Otp';
import { PasswordStrength } from '@/components/ui/PasswordStrength';
import { EMPTY, completeReset, requestReset } from '@/lib/actions/account';

export function ForgotPasswordForm() {
  const [requestState, requestAction, isRequesting] = useActionState(requestReset, EMPTY);
  const [resetState, resetAction, isResetting] = useActionState(completeReset, EMPTY);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [acknowledged, setAcknowledged] = useState(false);
  const [sent, setSent] = useState(false);

  if (!sent) {
    return (
      <form
        action={(form) => {
          requestAction(form);
          setSent(true);
        }}
        className="flex flex-col gap-6"
      >
        <header>
          <h1 className="text-[length:var(--text-title)] font-semibold">
            Forgot password
          </h1>
          <p className="mt-2 leading-relaxed text-text-secondary">
            If an email is on your account, we will send a code to it. If there is no
            email, nothing can be recovered — that is the cost of collecting nothing.
          </p>
        </header>

        <Field
          label="Username"
          name="username"
          value={username}
          onChange={(event) => setUsername(event.target.value.toLowerCase())}
          required
        />

        <Button type="submit" isLoading={isRequesting} disabled={!username.trim()}>
          Send code
        </Button>
      </form>
    );
  }

  return (
    <form action={resetAction} className="flex flex-col gap-6">
      <header>
        <h1 className="text-[length:var(--text-title)] font-semibold">Enter your code</h1>
        <p className="mt-2 text-text-secondary">{requestState.ok}</p>
      </header>

      <input type="hidden" name="username" value={username} />
      <Otp hasError={Boolean(resetState.error)} />

      <div className="rounded-[length:var(--radius-md)] border border-danger bg-surface p-5">
        <h2 className="font-bold text-danger">Read this before continuing</h2>
        <p className="mt-2 text-[length:var(--text-label)] leading-relaxed text-text-secondary">
          A reset gives you back your account, not your vault. Anything encrypted with
          your old password becomes permanently unreadable. Nobody can undo this,
          including us.
        </p>
      </div>

      <label className="flex cursor-pointer items-start gap-3">
        <input
          type="checkbox"
          checked={acknowledged}
          onChange={(event) => setAcknowledged(event.target.checked)}
          className="mt-0.5 size-[22px] shrink-0 accent-[var(--c-danger)]"
        />
        <span className="text-[length:var(--text-label)] text-text-secondary">
          I understand my vault cannot be recovered.
        </span>
      </label>

      <div className="flex flex-col gap-2">
        <Field
          label="New password"
          name="new_password"
          type="password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          required
          error={resetState.error}
        />
        <PasswordStrength password={password} />
      </div>

      <Button
        type="submit"
        isLoading={isResetting}
        disabled={!acknowledged || password.length < 10}
      >
        Reset password
      </Button>
    </form>
  );
}
