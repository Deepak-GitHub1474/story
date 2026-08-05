'use client';

import { useRouter } from 'next/navigation';
import { useTransition } from 'react';
import { markRead } from '@/lib/actions/notifications';

export function NotificationLink({
  notificationId,
  href,
  isRead,
  children,
}: {
  notificationId: string;
  href: string;
  isRead: boolean;
  children: React.ReactNode;
}) {
  const router = useRouter();
  const [, startTransition] = useTransition();

  return (
    <a
      href={href}
      onClick={(event) => {
        event.preventDefault();
        startTransition(async () => {
          if (!isRead) await markRead(notificationId);
          router.push(href);
        });
      }}
      className={
        isRead
          ? 'flex items-start gap-3 py-4 transition-colors hover:bg-surface'
          : 'flex items-start gap-3 bg-accent/6 py-4 transition-colors hover:bg-surface'
      }
    >
      {children}
    </a>
  );
}
