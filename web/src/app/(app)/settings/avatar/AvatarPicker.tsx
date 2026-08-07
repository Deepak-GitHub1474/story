'use client';

import { useRouter } from 'next/navigation';
import { useState, useTransition } from 'react';
import { Avatar } from '@/components/Avatar';
import { Button } from '@/components/ui/Button';
import { cn } from '@/lib/cn';
import { newAvatarSeeds } from '@/lib/avatarSeeds';
import { setAvatarSeed } from '@/lib/actions/account';

const BATCH = 24;

export function AvatarPicker({ current }: { current: string }) {
  const router = useRouter();
  const [seeds, setSeeds] = useState(() => newAvatarSeeds(BATCH, current));
  const [chosen, setChosen] = useState(current);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  return (
    <div className="mx-auto max-w-lg">
      <h1 className="text-[length:var(--text-title)] font-semibold">Your avatar</h1>

      <div className="mt-6 flex items-start gap-5">
        <Avatar seed={chosen} size={76} />
        <p className="leading-relaxed text-text-secondary">
          Every avatar is drawn in your browser from a short code. Nothing is
          uploaded, and no picture of you exists to leak.
        </p>
      </div>

      <ul className="mt-8 grid grid-cols-4 gap-4 sm:grid-cols-6">
        {seeds.map((seed) => (
          <li key={seed}>
            <button
              type="button"
              aria-pressed={seed === chosen}
              onClick={() => setChosen(seed)}
              className={cn(
                'rounded-full border-2 p-0.5 transition-colors',
                seed === chosen ? 'border-accent' : 'border-transparent',
              )}
            >
              <Avatar seed={seed} size={52} />
            </button>
          </li>
        ))}
      </ul>

      {error ? (
        <p role="alert" className="mt-5 text-[length:var(--text-label)] text-danger">
          {error}
        </p>
      ) : null}

      <div className="mt-8 flex flex-wrap gap-3">
        <Button
          isFullWidth={false}
          isLoading={isPending}
          onClick={() =>
            startTransition(async () => {
              const result = await setAvatarSeed(chosen);
              if (result.error) setError(result.error);
              else router.push('/settings');
            })
          }
        >
          Use this avatar
        </Button>
        <Button
          variant="secondary"
          isFullWidth={false}
          onClick={() => setSeeds(newAvatarSeeds(BATCH, chosen))}
        >
          Show me more
        </Button>
      </div>
    </div>
  );
}
