'use client';

import { useOptimistic, useTransition } from 'react';
import { Switch } from '@/components/ui/Switch';
import { setNotifications } from '@/lib/actions/account';

export function NotificationToggle({ enabled }: { enabled: boolean }) {
  const [isOn, setOptimistic] = useOptimistic(enabled, (_, next: boolean) => next);
  const [, startTransition] = useTransition();

  return (
    <Switch
      isOn={isOn}
      label="In-app notifications"
      onToggle={() =>
        startTransition(async () => {
          const next = !isOn;
          setOptimistic(next);
          await setNotifications(next);
        })
      }
    />
  );
}
