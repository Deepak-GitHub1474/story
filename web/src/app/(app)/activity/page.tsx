import type { Metadata } from 'next';
import { Avatar } from '@/components/Avatar';
import { EmptyState } from '@/components/EmptyState';
import { KindBadge } from './KindBadge';
import { MarkAllRead } from './MarkAllRead';
import { NotificationLink } from './NotificationLink';
import { backendFetch } from '@/lib/server/session';
import { relativeTime } from '@/lib/format';
import type { TNotification, TPage } from '@/lib/types';

export const metadata: Metadata = { title: 'Activity' };

export default async function ActivityPage() {
  const result = await backendFetch<TPage<TNotification>>('/notifications?limit=30');
  const items = result.ok ? result.value.items : [];
  const unread = items.filter((item) => !item.is_read).length;

  return (
    <div className="mx-auto max-w-2xl">
      <div className="flex items-center justify-between gap-4">
        <h1 className="text-[length:var(--text-title)] font-semibold">Activity</h1>
        {unread > 0 ? <MarkAllRead /> : null}
      </div>

      {items.length === 0 ? (
        <EmptyState
          title="Nothing yet"
          body="When someone reads and responds to your stories, it shows up here. Only things about you, nothing else."
        />
      ) : (
        <ul className="mt-6 divide-y divide-border border-y border-border">
          {items.map((item) => (
            <li key={item.notification_id}>
              <NotificationLink
                notificationId={item.notification_id}
                isRead={item.is_read}
                href={
                  item.target?.kind === 'story' ? `/story/${item.target.id}` : '/activity'
                }
              >
                <span className="relative shrink-0">
                  <Avatar seed={item.actor.avatar_seed} size={40} />
                  <KindBadge kind={item.kind} />
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block leading-relaxed text-text-secondary">
                    <span className="font-semibold text-text-primary">
                      {item.actor.display_name}
                    </span>{' '}
                    {item.body}
                  </span>
                  <span className="block text-[length:var(--text-caption)] text-text-muted">
                    {relativeTime(item.created_at)}
                  </span>
                </span>
                {!item.is_read ? (
                  <span
                    aria-label="Unread"
                    className="mt-2 size-2 shrink-0 rounded-full bg-accent"
                  />
                ) : null}
              </NotificationLink>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
