'use client';

import { useActionState, useState } from 'react';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { Otp } from '@/components/ui/Otp';
import { AsyncButton } from '@/components/AsyncButton';
import {
  addEmail,
  removeEmail,
  resendEmailCode,
  verifyEmail,
} from '@/lib/actions/account';
import { EMPTY } from '@/lib/actions/state';

export function EmailForm({
  masked,
  verified,
}: {
  masked: string | null;
  verified: boolean;
}) {
  const [addState, addAction, isAdding] = useActionState(addEmail, EMPTY);
  const [verifyState, verifyAction, isVerifying] = useActionState(verifyEmail, EMPTY);
  const [stage, setStage] = useState<'idle' | 'code'>(masked && !verified ? 'code' : 'idle');

  return (
    <div className="mx-auto flex max-w-lg flex-col gap-6">
      <header>
        <h1 className="text-[length:var(--text-title)] font-semibold">Recovery email</h1>
        <p className="mt-2 leading-relaxed text-text-secondary">
          An email is the only way to recover a forgotten password. We store it
          encrypted and can never show it to you or anyone else — only send to it.
        </p>
      </header>

      {masked ? (
        <p className="rounded-[length:var(--radius-md)] border border-border bg-surface px-4 py-3">
          <span className="font-semibold">{masked}</span>{' '}
          <span className={verified ? 'text-success' : 'text-text-muted'}>
            {verified ? '· Verified' : '· Not verified yet'}
          </span>
        </p>
      ) : null}

      {masked ? (
        <AsyncButton
          label="Remove this email"
          variant="ghost"
          action={removeEmail}
          confirmText="Remove your recovery email? Without one, a forgotten password cannot be recovered and your vault is lost with it."
        />
      ) : null}

      {stage === 'idle' || !masked ? (
        <form
          action={(form) => {
            addAction(form);
            setStage('code');
          }}
          className="flex flex-col gap-6"
        >
          <Field
            label="Email address"
            name="email"
            type="email"
            placeholder="you@example.com"
            required
            error={addState.error}
          />
          <Button type="submit" isLoading={isAdding}>
            Send code
          </Button>
        </form>
      ) : (
        <form action={verifyAction} className="flex flex-col gap-6">
          <p className="text-text-secondary">Enter the 6-digit code we sent.</p>
          <Otp hasError={Boolean(verifyState.error)} />
          {verifyState.error ? (
            <p role="alert" className="text-[length:var(--text-label)] text-danger">
              {verifyState.error}
            </p>
          ) : null}
          {verifyState.ok ? (
            <p role="status" className="text-[length:var(--text-label)] text-success">
              {verifyState.ok}
            </p>
          ) : null}
          <Button type="submit" isLoading={isVerifying}>
            Verify
          </Button>
          <button
            type="button"
            onClick={() => setStage('idle')}
            className="text-[length:var(--text-label)] text-text-muted hover:text-text-secondary"
          >
            Use a different address
          </button>
        </form>
      )}
    </div>
  );
}
