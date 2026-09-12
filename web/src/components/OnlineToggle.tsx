'use client';

import { useOptimistic, useTransition } from 'react';
import { Switch } from '@/components/ui/Switch';
import { setOnlineStatus } from '@/lib/actions/account';

export function OnlineToggle({ enabled }: { enabled: boolean }) {
  const [isOn, setOptimistic] = useOptimistic(enabled, (_, next: boolean) => next);
  const [, startTransition] = useTransition();

  return (
    <Switch
      isOn={isOn}
      label="Show when I am online"
      onToggle={() =>
        startTransition(async () => {
          const next = !isOn;
          setOptimistic(next);
          await setOnlineStatus(next);
        })
      }
    />
  );
}
