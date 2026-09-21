'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { Avatar } from '@/components/Avatar';
import { ChatUnlock } from '@/components/ChatUnlock';
import { EmptyState } from '@/components/EmptyState';
import { cn } from '@/lib/cn';
import { relativeTime } from '@/lib/format';
import { useChatIdentity } from '@/lib/chat/useIdentity';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { deleteConversation } from '@/lib/actions/chat';
import type { TConversation } from '@/lib/chat/types';

export function ChatList({ userId }: { userId: string }) {
  const identity = useChatIdentity(userId);
  const [showRequests, setShowRequests] = useState(false);
  const [items, setItems] = useState<TConversation[] | null>(null);
  const [removing, setRemoving] = useState<TConversation | null>(null);

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
    <div className="max-w-2xl">
      <div className="flex items-center justify-between gap-4">
        <h1 className="text-[length:var(--text-heading)] font-medium sm:font-editorial sm:text-[length:var(--text-title)] sm:font-semibold sm:tracking-[var(--tracking-title)]">Messages</h1>
        <Link
          href="/chats/new"
          className="inline-flex h-9 shrink-0 items-center rounded-[length:var(--radius-pill)] bg-surface-raised px-4 whitespace-nowrap text-[length:var(--text-label)] font-medium text-text-secondary transition-colors duration-[var(--motion-fast)] hover:text-text-primary"
        >
          New message
        </Link>
      </div>

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
              'inline-flex h-9 items-center rounded-[length:var(--radius-md)] border px-4 text-[length:var(--text-caption)] font-medium tracking-[var(--tracking-label)] transition-colors duration-[var(--motion-fast)]',
              showRequests === pending
                ? 'border-accent bg-accent-strong text-accent-text'
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
              : 'Start one from New message, or find someone in search. If you both follow each other it opens straight away.'
          }
        />
      ) : (
        <ul className="mt-6 divide-y divide-border border-y border-border">
          {items.map((conversation) => (
            <li key={conversation.conversation_id} className="group/row relative">
              <Link
                href={`/chats/${conversation.conversation_id}`}
                className="flex items-center gap-4 py-4 pr-9 transition-colors hover:bg-surface"
              >
                <Avatar seed={conversation.other.avatar_seed} size={48} />
                <span className="min-w-0 flex-1">
                  <span
                    className={cn(
                      'block truncate',
                      conversation.unread_count > 0
                        ? 'font-medium'
                        : 'font-medium',
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
                  <span className="rounded-[length:var(--radius-pill)] bg-accent-strong px-2 py-0.5 text-[length:var(--text-caption)] font-medium text-accent-text">
                    {conversation.unread_count}
                  </span>
                ) : null}
              </Link>

              <button
                type="button"
                aria-label={`Options for ${conversation.other.display_name}`}
                onClick={() => setRemoving(conversation)}
                className="absolute top-1/2 right-0 grid size-7 -translate-y-1/2 place-items-center rounded-[length:var(--radius-sm)] text-text-muted opacity-0 transition-opacity duration-[var(--motion-fast)] group-hover/row:opacity-100 hover:bg-surface-raised hover:text-text-primary focus-visible:opacity-100 [@media(hover:none)]:opacity-100"
              >
                <svg viewBox="0 0 24 24" aria-hidden="true" className="size-4" fill="currentColor">
                  <circle cx="5" cy="12" r="1.6" />
                  <circle cx="12" cy="12" r="1.6" />
                  <circle cx="19" cy="12" r="1.6" />
                </svg>
              </button>
            </li>
          ))}
        </ul>
      )}

      <ConfirmDialog
        isOpen={removing !== null}
        title={removing ? `Delete chat with ${removing.other.display_name}?` : ''}
        body="It disappears from your list and the messages stop showing for you. Their copy is untouched — this does not delete it for them."
        confirmLabel="Delete"
        isDanger
        onCancel={() => setRemoving(null)}
        onConfirm={() => {
          const target = removing;
          setRemoving(null);
          if (!target) return;
          setItems((current) =>
            (current ?? []).filter(
              (row) => row.conversation_id !== target.conversation_id,
            ),
          );
          void deleteConversation(target.conversation_id);
        }}
      />
    </div>
  );
}
