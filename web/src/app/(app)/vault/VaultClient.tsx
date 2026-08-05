'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { Card } from '@/components/ui/Surface';

export function VaultClient({
  hasPasscode,
  itemCount,
  usedBytes,
  limitBytes,
}: {
  hasPasscode: boolean;
  itemCount: number;
  usedBytes: number;
  limitBytes: number;
}) {
  const [password, setPassword] = useState('');
  const [passcode, setPasscode] = useState('');
  const [error, setError] = useState<string | null>(null);

  const usedMb = (usedBytes / 1048576).toFixed(1);
  const limitGb = (limitBytes / 1073741824).toFixed(0);

  return (
    <div className="mx-auto max-w-lg">
      <h1 className="text-[length:var(--text-title)] font-semibold">Vault</h1>

      <Card className="mt-6">
        <p className="leading-relaxed text-text-secondary">
          Two secrets open this vault: your account password and your vault passcode. We
          hold neither. Files are encrypted in this browser before they leave it, so a
          full copy of our database yields nothing.
        </p>
      </Card>

      <p className="mt-4 text-[length:var(--text-caption)] text-text-muted">
        {itemCount} items · {usedMb} MB of {limitGb} GB used
      </p>

      {!hasPasscode ? (
        <Card className="mt-6 border-accent">
          <h2 className="font-semibold">Set up your vault first</h2>
          <p className="mt-2 leading-relaxed text-text-secondary">
            Create a vault passcode in the mobile app. Key setup happens on a device you
            control, never in a browser tab, because that is where the master key is
            generated.
          </p>
        </Card>
      ) : (
        <form
          className="mt-8 flex flex-col gap-6"
          onSubmit={(event) => {
            event.preventDefault();
            setError(
              'Browser unlock is not enabled yet. Open your vault in the mobile app.',
            );
          }}
        >
          <Field
            label="Account password"
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            autoComplete="current-password"
          />
          <Field
            label="Vault passcode"
            type="password"
            value={passcode}
            onChange={(event) => setPasscode(event.target.value)}
            error={error}
          />
          <Button type="submit" disabled={!password || !passcode}>
            Unlock
          </Button>
        </form>
      )}

      <a
        href="/vault/recovery"
        className="mt-8 inline-block text-[length:var(--text-label)] text-accent underline-offset-4 hover:underline"
      >
        Lost your vault passcode?
      </a>

      <p className="mt-6 text-[length:var(--text-caption)] leading-relaxed text-text-muted">
        Browsers cannot block screenshots the way a phone can, and there is no biometric
        unlock here. Those limits are real, so the vault opens on mobile first.
      </p>
    </div>
  );
}
