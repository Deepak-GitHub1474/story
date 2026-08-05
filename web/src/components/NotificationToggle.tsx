'use client';

import { useOptimistic, useTransition } from 'react';
import { cn } from '@/lib/cn';
import { setNotifications } from '@/lib/actions/account';

export function NotificationToggle({ enabled }: { enabled: boolean }) {
  const [isOn, setOptimistic] = useOptimistic(enabled, (_, next: boolean) => next);
  const [, startTransition] = useTransition();

  return (
    <button
      type="button"
      role="switch"
      aria-checked={isOn}
      aria-label="In-app notifications"
      onClick={() =>
        startTransition(async () => {
          const next = !isOn;
          setOptimistic(next);
          await setNotifications(next);
        })
      }
      className={cn(
        'relative h-7 w-12 shrink-0 rounded-[length:var(--radius-pill)] transition-colors',
        isOn ? 'bg-accent' : 'bg-border',
      )}
    >
      <span
        className={cn(
          'absolute top-1 size-5 rounded-full bg-bg transition-transform duration-200',
          isOn ? 'translate-x-6' : 'translate-x-1',
        )}
      />
    </button>
  );
}
