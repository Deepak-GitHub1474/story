'use client';

import { useOptimistic, useTransition } from 'react';
import { cn } from '@/lib/cn';
import { setOnlineStatus } from '@/lib/actions/account';

export function OnlineToggle({ enabled }: { enabled: boolean }) {
  const [isOn, setOptimistic] = useOptimistic(enabled);
  const [, startTransition] = useTransition();

  return (
    <button
      type="button"
      role="switch"
      aria-checked={isOn}
      aria-label="Show when I am online"
      onClick={() =>
        startTransition(async () => {
          setOptimistic(!isOn);
          await setOnlineStatus(!isOn);
        })
      }
      className={cn(
        'relative h-6 w-11 rounded-full transition-colors',
        isOn ? 'bg-accent' : 'bg-surface-raised',
      )}
    >
      <span
        className={cn(
          'absolute top-0.5 size-5 rounded-full bg-bg transition-transform',
          isOn ? 'translate-x-[22px]' : 'translate-x-0.5',
        )}
      />
    </button>
  );
}
