'use client';

import { useState, useTransition } from 'react';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { listPasscodes, releaseEscrow } from '@/lib/actions';

type TPasscode = {
  passcode_id: string;
  label: string;
  scope: string;
  failed_attempts: number;
  created_at: string;
  last_used_at: string | null;
};

export function VaultLookup() {
  const [username, setUsername] = useState('');
  const [passcodes, setPasscodes] = useState<TPasscode[] | null>(null);
  const [ticketId, setTicketId] = useState('');
  const [totpCode, setTotpCode] = useState('');
  const [justification, setJustification] = useState('');
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  return (
    <div className="space-y-8">
      <form
        onSubmit={(event) => {
          event.preventDefault();
          startTransition(async () => {
            const result = await listPasscodes(username.trim().toLowerCase());
            if (result.error) {
              setError(result.error);
              setPasscodes(null);
            } else {
              setError(null);
              setPasscodes(result.items as TPasscode[]);
            }
          });
        }}
        className="flex flex-col gap-4"
      >
        <Field
          label="Account username"
          value={username}
          onChange={(event) => setUsername(event.target.value)}
          autoCapitalize="none"
          spellCheck={false}
          error={error}
          hint="Looking this up is recorded in the audit log."
        />
        <Button type="submit" isLoading={isPending} disabled={!username.trim()}>
          List passcode names
        </Button>
      </form>

      {passcodes ? (
        passcodes.length === 0 ? (
          <p className="text-text-secondary">This account has no vault passcodes.</p>
        ) : (
          <>
            <ul className="divide-y divide-border rounded-[length:var(--radius-md)] border border-border">
              {passcodes.map((passcode) => (
                <li key={passcode.passcode_id} className="px-4 py-3">
                  <p className="font-semibold">{passcode.label}</p>
                  <p className="text-[length:var(--text-caption)] text-text-muted">
                    {passcode.scope} · {passcode.failed_attempts} failed attempts
                  </p>
                </li>
              ))}
            </ul>

            <form
              onSubmit={(event) => {
                event.preventDefault();
                startTransition(async () => {
                  const result = await releaseEscrow(
                    username.trim().toLowerCase(),
                    ticketId.trim(),
                    justification.trim(),
                    totpCode.trim(),
                  );
                  if (result.error) {
                    setError(result.error);
                  } else {
                    setError(null);
                    setNotice('Released to the account owner.');
                    setTicketId('');
                    setJustification('');
                    setTotpCode('');
                  }
                });
              }}
              className="flex flex-col gap-4 rounded-[length:var(--radius-md)] border border-danger bg-surface p-5"
            >
              <h2 className="font-semibold text-danger">Release to the owner</h2>
              <Field
                label="Ticket id"
                value={ticketId}
                onChange={(event) => setTicketId(event.target.value)}
                placeholder="tkt_…"
                hint="Must be an open passcode_release ticket opened by this account."
              />
              <div className="flex flex-col gap-2">
                <label
                  htmlFor="justification"
                  className="text-[length:var(--text-label)] font-medium text-text-secondary"
                >
                  Justification
                </label>
                <textarea
                  id="justification"
                  value={justification}
                  onChange={(event) => setJustification(event.target.value)}
                  rows={3}
                  minLength={50}
                  className="resize-y rounded-[length:var(--radius-md)] border border-border bg-bg px-4 py-3 outline-none focus:border-accent"
                />
                <p className="text-[length:var(--text-caption)] text-text-muted">
                  At least 50 characters. Stored in the audit log the owner can read.
                </p>
              </div>
              <Field
                label="Authenticator code"
                value={totpCode}
                onChange={(event) =>
                  setTotpCode(event.target.value.replace(/[^a-z0-9]/gi, ''))
                }
                inputMode="numeric"
                maxLength={10}
                hint="From your authenticator app, or one backup code."
              />
              <Button
                type="submit"
                variant="danger"
                isLoading={isPending}
                disabled={
                  !ticketId.trim() ||
                  justification.trim().length < 50 ||
                  totpCode.trim().length < 6
                }
              >
                Release
              </Button>
              {notice ? (
                <p role="status" className="text-[length:var(--text-label)] text-success">
                  {notice}
                </p>
              ) : null}
            </form>
          </>
        )
      ) : null}
    </div>
  );
}
