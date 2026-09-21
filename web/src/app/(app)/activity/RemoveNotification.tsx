'use client';

import { useTransition } from 'react';
import { removeNotification } from '@/lib/actions/notifications';

export function RemoveNotification({ notificationId }: { notificationId: string }) {
  const [isPending, startTransition] = useTransition();

  return (
    <button
      type="button"
      aria-label="Remove this from activity"
      title="Remove"
      disabled={isPending}
      onClick={() =>
        startTransition(async () => void (await removeNotification(notificationId)))
      }
      className="shrink-0 self-center px-3 py-2 text-text-muted transition-colors hover:text-danger disabled:opacity-50"
    >
      <svg
        viewBox="0 0 24 24"
        aria-hidden="true"
        className="size-[var(--size-icon-md)]"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      >
        <path d="M6 6 18 18M18 6 6 18" />
      </svg>
    </button>
  );
}
