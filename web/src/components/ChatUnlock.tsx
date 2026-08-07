'use client';

import { useState, useTransition } from 'react';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { unlockWithPassword } from '@/lib/chat/useIdentity';

export function ChatUnlock({ userId }: { userId: string }) {
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  return (
    <form
      className="mt-8 flex max-w-md flex-col gap-5 rounded-[length:var(--radius-md)] border border-border bg-surface p-6"
      onSubmit={(event) => {
        event.preventDefault();
        startTransition(async () => {
          try {
            const ok = await unlockWithPassword(userId, password);
            if (ok) window.location.reload();
            else setError('No chat key backup on this account yet.');
          } catch {
            setError('That password did not unlock your chat key.');
          }
        });
      }}
    >
      <div>
        <h2 className="font-semibold">Unlock your messages here</h2>
        <p className="mt-2 leading-relaxed text-text-secondary">
          Your usual account password — the same one you sign in with. Your chat key
          is stored encrypted and only that password opens it, so this browser can
          read the same conversations your phone can.
        </p>
      </div>

      <Field
        label="Your account password"
        type="password"
        value={password}
        onChange={(event) => setPassword(event.target.value)}
        autoComplete="current-password"
        error={error}
      />

      <Button type="submit" isLoading={isPending} disabled={!password}>
        Unlock
      </Button>
    </form>
  );
}
