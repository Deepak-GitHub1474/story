'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useState, useTransition } from 'react';
import { Avatar } from '@/components/Avatar';
import { EmptyState } from '@/components/EmptyState';
import { newConversationKey, pairKey, wrapForPeer } from '@/lib/chat/crypto';
import { useChatIdentity } from '@/lib/chat/useIdentity';
import { peerIdentity, peopleToMessage, startConversation } from '@/lib/actions/chat';
import type { TPersonToMessage } from '@/lib/chat/types';

export function NewChat({ viewerId }: { viewerId: string }) {
  const router = useRouter();
  const identity = useChatIdentity(viewerId);
  const [people, setPeople] = useState<TPersonToMessage[] | null>(null);
  const [cursor, setCursor] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(false);
  const [opening, setOpening] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, startLoading] = useTransition();

  useEffect(() => {
    let cancelled = false;
    void peopleToMessage(null).then(({ page, error: failed }) => {
      if (cancelled) return;
      if (!page) {
        setError(failed);
        setPeople([]);
        return;
      }
      setPeople(page.items);
      setCursor(page.next_cursor);
      setHasMore(page.has_more);
    });
    return () => {
      cancelled = true;
    };
  }, []);

  function more() {
    startLoading(async () => {
      const { page, error: failed } = await peopleToMessage(cursor);
      if (!page) {
        setError(failed);
        return;
      }
      setPeople((current) => [...(current ?? []), ...page.items]);
      setCursor(page.next_cursor);
      setHasMore(page.has_more);
    });
  }

  function open(person: TPersonToMessage) {
    if (identity.status !== 'ready') {
      setError('This browser cannot do the encryption chat needs.');
      return;
    }

    setOpening(person.user_id);
    setError(null);

    startLoading(async () => {
      try {
        const peer = await peerIdentity(person.username);
        if (!peer) {
          setError(
            'They have not signed in since chat was added, so their device has no key yet.',
          );
          return;
        }

        const cek = await newConversationKey();
        const pair = pairKey(viewerId, peer.user_id);

        const id = await startConversation({
          username: person.username,
          wrapped_cek_for_me: await wrapForPeer({
            cek,
            mine: identity.identity,
            theirPublicKey: peer.public_key,
            pair,
            recipientId: viewerId,
          }),
          wrapped_cek_for_them: await wrapForPeer({
            cek,
            mine: identity.identity,
            theirPublicKey: peer.public_key,
            pair,
            recipientId: peer.user_id,
          }),
          sender_public_key: identity.identity.publicKey,
        });

        if (id) router.push(`/chats/${id}`);
        else setError('Could not open that chat.');
      } finally {
        setOpening(null);
      }
    });
  }

  return (
    <div className="max-w-2xl">
      <div className="flex items-center justify-between gap-4">
        <h1 className="font-editorial text-[length:var(--text-title)] font-semibold tracking-[var(--tracking-title)]">New message</h1>
        <Link
          href="/chats"
          className="text-[length:var(--text-label)] text-text-muted hover:text-text-primary"
        >
          Close
        </Link>
      </div>

      <p className="mt-2 leading-relaxed text-text-secondary">
        People you follow who you have not messaged yet. If they follow you back the
        chat opens straight away; otherwise it waits in their requests.
      </p>

      {identity.status === 'unsupported' ? (
        <p className="mt-4 rounded-[length:var(--radius-md)] border border-danger bg-surface px-4 py-3 leading-relaxed text-text-secondary">
          This browser cannot do the encryption chat needs. Messages open in the mobile
          app.
        </p>
      ) : null}

      {error ? (
        <p role="alert" className="mt-4 text-[length:var(--text-label)] text-danger">
          {error}
        </p>
      ) : null}

      {people === null ? null : people.length === 0 ? (
        <EmptyState
          title="Nobody to message yet"
          body="Follow someone first, or find them from search. People you follow show up here."
        />
      ) : (
        <ul className="mt-6 divide-y divide-border border-y border-border">
          {people.map((person) => (
            <li key={person.user_id}>
              <button
                type="button"
                onClick={() => open(person)}
                disabled={opening !== null || identity.status !== 'ready'}
                className="flex w-full items-center gap-3 py-4 text-left transition-opacity disabled:opacity-55"
              >
                <Avatar seed={person.avatar_seed} size={40} />
                <span className="min-w-0 flex-1">
                  <span className="block truncate font-medium">
                    {person.display_name}
                  </span>
                  <span className="block truncate text-[length:var(--text-caption)] text-text-muted">
                    @{person.username}
                    {person.opens_straight_away ? ' · opens straight away' : ' · goes to requests'}
                  </span>
                </span>
                {opening === person.user_id ? (
                  <span className="text-[length:var(--text-caption)] text-text-muted">
                    Opening…
                  </span>
                ) : null}
              </button>
            </li>
          ))}
        </ul>
      )}

      {hasMore ? (
        <button
          type="button"
          onClick={more}
          disabled={isLoading}
          className="w-full py-4 text-center text-[length:var(--text-label)] text-accent hover:underline"
        >
          {isLoading ? 'Loading…' : 'Show more'}
        </button>
      ) : null}
    </div>
  );
}
