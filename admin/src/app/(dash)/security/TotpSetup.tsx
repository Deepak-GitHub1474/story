'use client';

import { useState, useTransition } from 'react';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { confirmTotp, disableTotp, startTotp } from '@/lib/actions';

export function TotpSetup({
  isEnabled,
  backupsLeft,
}: {
  isEnabled: boolean;
  backupsLeft: number;
}) {
  const [secret, setSecret] = useState<string | null>(null);
  const [code, setCode] = useState('');
  const [backupCodes, setBackupCodes] = useState<string[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  if (backupCodes) {
    return (
      <div className="rounded-[length:var(--radius-md)] border border-danger bg-surface p-5">
        <h2 className="font-bold text-danger">Save these now</h2>
        <p className="mt-2 leading-relaxed text-text-secondary">
          Each one works once, in place of a code, if you lose your phone. They are
          shown here and nowhere else, ever.
        </p>
        <ul className="mt-4 grid grid-cols-2 gap-2 font-mono text-[length:var(--text-label)]">
          {backupCodes.map((backup) => (
            <li
              key={backup}
              className="rounded-[length:var(--radius-sm)] bg-surface-raised px-3 py-2"
            >
              {backup}
            </li>
          ))}
        </ul>
      </div>
    );
  }

  if (isEnabled) {
    return (
      <div className="rounded-[length:var(--radius-md)] border border-border bg-surface p-5">
        <p className="font-semibold text-success">Authenticator active</p>
        <p className="mt-2 text-[length:var(--text-label)] text-text-secondary">
          {backupsLeft} backup {backupsLeft === 1 ? 'code' : 'codes'} left.
        </p>
        <div className="mt-4">
          <Button
            variant="danger"
            isFullWidth={false}
            isLoading={isPending}
            onClick={() =>
              startTransition(async () => {
                if (
                  confirm(
                    'Remove your authenticator? You will not be able to approve a passcode release until you set one up again.',
                  )
                ) {
                  await disableTotp();
                }
              })
            }
          >
            Remove authenticator
          </Button>
        </div>
      </div>
    );
  }

  if (!secret) {
    return (
      <Button
        isFullWidth={false}
        isLoading={isPending}
        onClick={() =>
          startTransition(async () => {
            const result = await startTotp();
            if (result.error) setError(result.error);
            else setSecret(result.secret);
          })
        }
      >
        Set up an authenticator
      </Button>
    );
  }

  return (
    <div className="flex flex-col gap-5 rounded-[length:var(--radius-md)] border border-border bg-surface p-5">
      <div>
        <h2 className="font-semibold">1. Add this key to your app</h2>
        <p className="mt-2 leading-relaxed text-text-secondary">
          Open Google Authenticator, Aegis, 1Password or Bitwarden, choose &ldquo;enter
          a setup key&rdquo;, and paste this.
        </p>
        <p className="mt-3 rounded-[length:var(--radius-sm)] bg-surface-raised px-4 py-3 font-mono text-[length:var(--text-label)] break-all">
          {secret}
        </p>
      </div>

      <div>
        <h2 className="font-semibold">2. Confirm with the code it shows</h2>
        <div className="mt-3 flex flex-col gap-4">
          <Field
            label="Six digit code"
            value={code}
            onChange={(event) => setCode(event.target.value.replace(/\D/g, ''))}
            inputMode="numeric"
            maxLength={6}
            error={error}
          />
          <Button
            isFullWidth={false}
            isLoading={isPending}
            disabled={code.length !== 6}
            onClick={() =>
              startTransition(async () => {
                const result = await confirmTotp(code);
                if (result.error) setError(result.error);
                else setBackupCodes(result.backupCodes);
              })
            }
          >
            Confirm
          </Button>
        </div>
      </div>
    </div>
  );
}
