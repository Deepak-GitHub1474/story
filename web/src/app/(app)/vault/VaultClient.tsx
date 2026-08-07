'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { Card } from '@/components/ui/Surface';
import { cn } from '@/lib/cn';
import { useVault, type OpenItem } from '@/lib/vault/useVault';

const KINDS = [
  ['image', 'Photos'],
  ['video', 'Video'],
  ['pdf', 'Documents'],
];

const CHIP =
  'rounded-[length:var(--radius-pill)] border px-4 py-2 text-[length:var(--text-label)] font-semibold transition-colors';

export function VaultClient({
  userId,
  vaults,
  hasPasscode,
  itemCount,
  usedBytes,
  limitBytes,
}: {
  userId: string;
  vaults: { id: string; label: string }[];
  hasPasscode: boolean;
  itemCount: number;
  usedBytes: number;
  limitBytes: number;
}) {
  const vault = useVault(userId);
  const [password, setPassword] = useState('');
  const [passcode, setPasscode] = useState('');
  const [chosen, setChosen] = useState(vaults[0]?.id ?? '');
  const [kind, setKind] = useState<string | null>(null);
  const [secretWord, setSecretWord] = useState('');
  const [sealed, setSealed] = useState<OpenItem | null>(null);
  const [sealedMiss, setSealedMiss] = useState(false);
  const [opened, setOpened] = useState<{ url: string; item: OpenItem } | null>(null);

  const usedMb = (usedBytes / 1048576).toFixed(1);
  const limitGb = (limitBytes / 1073741824).toFixed(0);
  const shown = kind ? vault.items.filter((item) => item.kind === kind) : vault.items;

  async function view(item: OpenItem) {
    const url = await vault.open(item);
    if (url) setOpened({ url, item });
  }

  function close() {
    if (opened) URL.revokeObjectURL(opened.url);
    setOpened(null);
  }

  if (!vault.isUnlocked) {
    return (
      <div className="mx-auto max-w-lg">
        <h1 className="font-editorial text-[length:var(--text-title)] font-medium">
          Vault
        </h1>

        <Card className="mt-6">
          <p className="leading-relaxed text-text-secondary">
            Two secrets open this vault: your account password and your vault passcode.
            We hold neither. Files are decrypted inside this tab and never leave it
            readable, so a full copy of our database yields nothing.
          </p>
        </Card>

        <p className="mt-4 text-[length:var(--text-caption)] text-text-muted">
          {itemCount} items · {usedMb} MB of {limitGb} GB used
        </p>

        {!hasPasscode ? (
          <Card className="mt-6 border-accent">
            <h2 className="font-semibold">Set your vault up first</h2>
            <p className="mt-2 leading-relaxed text-text-secondary">
              Create a vault passcode in the app. Key setup happens on a device you
              control, never in a browser tab, because that is where the master key is
              generated.
            </p>
          </Card>
        ) : (
          <form
            className="mt-8 flex flex-col gap-6"
            onSubmit={(event) => {
              event.preventDefault();
              void vault.unlock(password, passcode, chosen).then((ok) => {
                if (ok) {
                  setPassword('');
                  setPasscode('');
                }
              });
            }}
          >
            {vaults.length > 1 ? (
              <fieldset>
                <legend className="text-[length:var(--text-caption)] font-semibold tracking-wide text-text-muted">
                  Which vault
                </legend>
                <div className="mt-3 flex flex-wrap gap-2">
                  {vaults.map((row) => (
                    <button
                      key={row.id}
                      type="button"
                      aria-pressed={chosen === row.id}
                      onClick={() => setChosen(row.id)}
                      className={cn(
                        CHIP,
                        chosen === row.id
                          ? 'border-accent bg-accent text-accent-text'
                          : 'border-border text-text-secondary hover:border-text-muted',
                      )}
                    >
                      {row.label}
                    </button>
                  ))}
                </div>
              </fieldset>
            ) : null}

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
              error={vault.error}
            />
            <Button
              type="submit"
              isLoading={vault.isWorking}
              disabled={!password || !passcode || vault.isWorking}
            >
              {vault.isWorking ? 'Working out the key' : 'Unlock'}
            </Button>
            {vault.isWorking ? (
              <p className="text-center text-[length:var(--text-caption)] leading-relaxed text-text-muted">
                This takes a couple of seconds on purpose. That slowness is what makes
                guessing your passcode expensive.
              </p>
            ) : null}
          </form>
        )}

        <a
          href="/vault/recovery"
          className="mt-8 inline-block text-[length:var(--text-label)] text-accent underline-offset-4 hover:underline"
        >
          Lost your vault passcode?
        </a>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-3xl">
      <div className="flex items-center justify-between gap-4">
        <h1 className="font-editorial text-[length:var(--text-title)] font-medium">
          {vaults.find((row) => row.id === chosen)?.label ?? 'Vault'}
        </h1>
        <Button variant="secondary" size="sm" isFullWidth={false} onClick={vault.lock}>
          Lock
        </Button>
      </div>

      <div className="mt-6 flex flex-wrap gap-2">
        <button
          type="button"
          onClick={() => setKind(null)}
          className={cn(
            CHIP,
            kind === null
              ? 'border-accent bg-accent text-accent-text'
              : 'border-border text-text-secondary hover:border-text-muted',
          )}
        >
          Everything
        </button>
        {KINDS.map(([value, label]) => (
          <button
            key={value}
            type="button"
            onClick={() => setKind(value)}
            className={cn(
              CHIP,
              kind === value
                ? 'border-accent bg-accent text-accent-text'
                : 'border-border text-text-secondary hover:border-text-muted',
            )}
          >
            {label}
          </button>
        ))}
      </div>

      {shown.length === 0 ? (
        <p className="mt-10 leading-relaxed text-text-secondary">
          Nothing here yet. Files are added from the app, where they can be encrypted
          before they ever touch a network.
        </p>
      ) : (
        <ul className="mt-8 grid gap-4 sm:grid-cols-2">
          {shown.map((item) => (
            <li key={item.item_id}>
              <button
                type="button"
                onClick={() => void view(item)}
                className="w-full rounded-[length:var(--radius-md)] border border-border p-4 text-left transition-colors hover:border-text-muted"
              >
                <p className="truncate font-semibold">{item.filename}</p>
                <p className="mt-1 text-[length:var(--text-caption)] text-text-muted">
                  {item.kind} · {(item.size_bytes / 1024).toFixed(0)} KB
                </p>
              </button>
            </li>
          ))}
        </ul>
      )}

      <div className="mt-12 border-t border-border pt-8">
        <h2 className="font-semibold">Sealed files</h2>
        <p className="mt-2 leading-relaxed text-text-secondary">
          Sealed files are listed nowhere. Type the exact word you sealed one under —
          capitals and all — and it comes back.
        </p>

        <form
          className="mt-4 flex gap-3"
          onSubmit={(event) => {
            event.preventDefault();
            void vault.findByLabel(secretWord).then((found) => {
              setSealed(found);
              setSealedMiss(found === null);
            });
          }}
        >
          <input
            value={secretWord}
            onChange={(event) => setSecretWord(event.target.value)}
            placeholder="The word"
            autoCapitalize="none"
            spellCheck={false}
            className="h-[var(--size-control-height)] flex-1 rounded-[length:var(--radius-md)] border border-border bg-surface px-4 outline-none focus:border-accent"
          />
          <Button type="submit" isFullWidth={false} disabled={!secretWord.trim()}>
            Find
          </Button>
        </form>

        {sealedMiss ? (
          <p className="mt-3 text-[length:var(--text-caption)] text-text-muted">
            Nothing answers to that word.
          </p>
        ) : null}

        {sealed ? (
          <button
            type="button"
            onClick={() => void view(sealed)}
            className="mt-4 w-full rounded-[length:var(--radius-md)] border border-accent p-4 text-left"
          >
            <p className="truncate font-semibold">{sealed.filename}</p>
            <p className="mt-1 text-[length:var(--text-caption)] text-text-muted">
              {sealed.kind} · {(sealed.size_bytes / 1024).toFixed(0)} KB
            </p>
          </button>
        ) : null}
      </div>

      {opened ? (
        <div className="fixed inset-0 z-50 flex flex-col bg-bg/95 p-6 backdrop-blur-sm">
          <div className="flex items-center justify-between gap-4">
            <p className="truncate font-semibold">{opened.item.filename}</p>
            <div className="flex gap-4">
              <a
                href={opened.url}
                download={opened.item.filename}
                className="text-[length:var(--text-label)] font-semibold text-accent"
              >
                Save
              </a>
              <button
                type="button"
                onClick={close}
                className="text-[length:var(--text-label)] font-semibold text-text-secondary"
              >
                Close
              </button>
            </div>
          </div>

          <div className="mt-6 flex flex-1 items-center justify-center overflow-auto">
            {opened.item.kind === 'image' ? (
              <img
                src={opened.url}
                alt={opened.item.filename}
                className="max-h-full max-w-full object-contain"
              />
            ) : opened.item.kind === 'video' ? (
              <video src={opened.url} controls className="max-h-full max-w-full" />
            ) : (
              <object data={opened.url} type={opened.item.mime} className="h-full w-full">
                <p className="text-text-secondary">
                  This browser will not show it inline. Use Save.
                </p>
              </object>
            )}
          </div>
        </div>
      ) : null}
    </div>
  );
}
