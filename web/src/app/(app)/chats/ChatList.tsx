'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { Avatar } from '@/components/Avatar';
import { ChatUnlock } from '@/components/ChatUnlock';
import { EmptyState } from '@/components/EmptyState';
import { cn } from '@/lib/cn';
import { relativeTime } from '@/lib/format';
import { useChatIdentity } from '@/lib/chat/useIdentity';
import type { TConversation } from '@/lib/chat/types';

export function ChatList({ userId }: { userId: string }) {
  const identity = useChatIdentity(userId);
  const [showRequests, setShowRequests] = useState(false);
  const [items, setItems] = useState<TConversation[] | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      const response = await fetch(
        `/api/chat${showRequests ? '?state=pending' : ''}`,
      );
      const page = (await response.json()) as { items: TConversation[] } | null;
      if (!cancelled) setItems(page?.items ?? []);
    }

    void load();
    const timer = setInterval(load, 8000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [showRequests]);

  return (
    <div className="mx-auto max-w-2xl">
      <h1 className="text-[length:var(--text-title)] font-semibold">Messages</h1>

      {identity.status === 'locked' ? <ChatUnlock userId={userId} /> : null}

      {identity.status === 'unsupported' ? (
        <p className="mt-4 rounded-[length:var(--radius-md)] border border-danger bg-surface px-4 py-3 leading-relaxed text-text-secondary">
          This browser cannot do the encryption chat needs. Messages open in the
          mobile app.
        </p>
      ) : null}

      <div className="mt-6 flex gap-2">
        {[
          ['Chats', false],
          ['Requests', true],
        ].map(([label, pending]) => (
          <button
            key={String(label)}
            type="button"
            onClick={() => setShowRequests(pending as boolean)}
            className={cn(
              'rounded-[length:var(--radius-pill)] border px-4 py-2 text-[length:var(--text-label)] font-semibold transition-colors',
              showRequests === pending
                ? 'border-accent bg-accent text-accent-text'
                : 'border-border text-text-secondary hover:text-text-primary',
            )}
          >
            {label}
          </button>
        ))}
      </div>

      {items === null ? null : items.length === 0 ? (
        <EmptyState
          title={showRequests ? 'No requests' : 'No messages yet'}
          body={
            showRequests
              ? 'People who do not follow you back land here first.'
              : 'Find someone from search and say something. If you both follow each other it opens straight away.'
          }
        />
      ) : (
        <ul className="mt-6 divide-y divide-border border-y border-border">
          {items.map((conversation) => (
            <li key={conversation.conversation_id}>
              <Link
                href={`/chats/${conversation.conversation_id}`}
                className="flex items-center gap-4 py-4 transition-colors hover:bg-surface"
              >
                <Avatar seed={conversation.other.avatar_seed} size={48} />
                <span className="min-w-0 flex-1">
                  <span
                    className={cn(
                      'block truncate',
                      conversation.unread_count > 0
                        ? 'font-semibold'
                        : 'font-semibold',
                    )}
                  >
                    {conversation.other.display_name}
                  </span>
                  <span className="block text-[length:var(--text-caption)] text-text-muted">
                    {conversation.state === 'pending'
                      ? conversation.is_requester
                        ? 'Request sent'
                        : 'Wants to send you a message'
                      : `@${conversation.other.username}`}
                  </span>
                </span>
                {conversation.other_online ? (
                  <span
                    aria-label="Online"
                    className="size-2 rounded-full bg-success"
                  />
                ) : null}
                {conversation.last_message_at ? (
                  <span className="text-[length:var(--text-caption)] text-text-muted">
                    {relativeTime(conversation.last_message_at)}
                  </span>
                ) : null}
                {conversation.unread_count > 0 ? (
                  <span className="rounded-[length:var(--radius-pill)] bg-accent px-2 py-0.5 text-[length:var(--text-caption)] font-semibold text-accent-text">
                    {conversation.unread_count}
                  </span>
                ) : null}
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
