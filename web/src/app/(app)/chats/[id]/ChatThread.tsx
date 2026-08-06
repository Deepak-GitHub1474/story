'use client';

import Link from 'next/link';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Avatar } from '@/components/Avatar';
import { Button } from '@/components/ui/Button';
import { ChatUnlock } from '@/components/ChatUnlock';
import { cn } from '@/lib/cn';
import { relativeTime } from '@/lib/format';
import {
  decryptMessage,
  encryptMessage,
  pairKey,
  unwrapFromPeer,
} from '@/lib/chat/crypto';
import { useChatIdentity } from '@/lib/chat/useIdentity';
import type { TChatMessage, TConversation } from '@/lib/chat/types';
import {
  acceptConversation,
  announceTyping,
  markConversationRead,
  peerIdentity,
  sendMessage,
  unsendMessage,
} from '@/lib/actions/chat';

export function ChatThread({
  conversationId,
  userId,
}: {
  conversationId: string;
  userId: string;
}) {
  const identity = useChatIdentity(userId);
  const [conversation, setConversation] = useState<TConversation | null>(null);
  const [messages, setMessages] = useState<TChatMessage[]>([]);
  const [draft, setDraft] = useState('');
  const [error, setError] = useState<string | null>(null);
  const cek = useRef<Uint8Array | null>(null);
  const lastTyping = useRef(0);

  const decorate = useCallback(
    async (raw: TChatMessage[]) => {
      const key = cek.current;
      if (!key) return raw;

      return Promise.all(
        raw.map(async (message) => {
          if (message.is_deleted || !message.ciphertext) return message;
          try {
            return {
              ...message,
              text: await decryptMessage(key, message.ciphertext, conversationId),
            };
          } catch {
            return message;
          }
        }),
      );
    },
    [conversationId],
  );

  useEffect(() => {
    if (identity.status !== 'ready') return;
    let cancelled = false;

    async function open() {
      const response = await fetch(`/api/chat?conversation=${conversationId}`);
      const data = (await response.json()) as {
        conversation: TConversation;
      } | null;
      if (!data || cancelled) return;

      const record = data.conversation;
      setConversation(record);

      const peer = await peerIdentity(record.other.username);
      if (peer && record.wrapped_cek && identity.status === 'ready') {
        try {
          cek.current = await unwrapFromPeer({
            wrapped: record.wrapped_cek,
            mine: identity.identity,
            theirPublicKey: peer.public_key,
            pair: pairKey(userId, record.other.user_id),
            recipientId: userId,
          });
        } catch {
          setError(
            'This chat was started on another device, so its key is not in this browser.',
          );
        }
      }
    }

    void open();
    return () => {
      cancelled = true;
    };
  }, [conversationId, identity, userId]);

  useEffect(() => {
    let cancelled = false;

    async function poll() {
      const [threadResponse, metaResponse] = await Promise.all([
        fetch(`/api/chat?conversation=${conversationId}&messages=1`),
        fetch(`/api/chat?conversation=${conversationId}`),
      ]);
      const page = (await threadResponse.json()) as {
        items: TChatMessage[];
      } | null;
      const meta = (await metaResponse.json()) as {
        conversation: TConversation;
      } | null;

      if (cancelled) return;
      if (meta) setConversation(meta.conversation);
      if (page) {
        const decorated = await decorate(page.items);
        if (!cancelled) setMessages(decorated);
        const newest = page.items[0];
        if (newest) await markConversationRead(conversationId, newest.message_id);
      }
    }

    void poll();
    const timer = setInterval(poll, 3000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [conversationId, decorate]);

  async function send() {
    const text = draft.trim();
    const key = cek.current;
    if (!text || !key) return;

    setDraft('');
    const ciphertext = await encryptMessage(key, text, conversationId);
    const ok = await sendMessage(conversationId, ciphertext);
    if (!ok) setError('That did not send.');
  }

  const other = conversation?.other;
  const isPending = conversation?.state === 'pending';
  const canWrite = !isPending || Boolean(conversation?.is_requester);

  return (
    <div className="mx-auto flex h-[calc(100dvh-8rem)] max-w-2xl flex-col">
      <header className="flex items-center gap-3 border-b border-border pb-4">
        {other ? (
          <>
            <Avatar seed={other.avatar_seed} size={40} />
            <div className="min-w-0 flex-1">
              <Link href={`/u/${other.username}`} className="block font-semibold">
                {other.display_name}
              </Link>
              <p
                className={cn(
                  'text-[length:var(--text-caption)]',
                  conversation?.other_typing ? 'text-accent' : 'text-text-muted',
                )}
              >
                {conversation?.other_typing
                  ? 'typing…'
                  : conversation?.other_online
                    ? 'Online'
                    : `@${other.username}`}
              </p>
            </div>
          </>
        ) : null}
      </header>

      {identity.status === 'locked' ? <ChatUnlock userId={userId} /> : null}

      {error ? (
        <p className="mt-3 rounded-[length:var(--radius-md)] bg-surface-raised px-4 py-3 leading-relaxed text-text-secondary">
          {error}
        </p>
      ) : null}

      <ol className="flex flex-1 flex-col-reverse gap-2 overflow-y-auto py-6">
        {messages.map((message) => {
          const isMine = message.sender_id === userId;
          const seen =
            isMine &&
            conversation?.their_last_read_message_id !== null &&
            conversation?.their_last_read_message_id !== undefined &&
            message.message_id <= conversation.their_last_read_message_id;

          return (
            <li
              key={message.message_id}
              className={cn('flex flex-col', isMine ? 'items-end' : 'items-start')}
            >
              <div
                className={cn(
                  'max-w-[76%] rounded-[length:var(--radius-lg)] px-4 py-2.5 leading-relaxed',
                  isMine
                    ? 'bg-accent text-accent-text'
                    : 'border border-border bg-surface',
                )}
              >
                {message.is_deleted ? (
                  <span className="text-text-muted italic">Unsent</span>
                ) : (
                  (message.text ?? 'Cannot be opened in this browser')
                )}
              </div>
              <div className="mt-1 flex items-center gap-2 text-[length:var(--text-caption)] text-text-muted">
                <span>{relativeTime(message.created_at)}</span>
                {seen ? <span className="text-accent">Seen</span> : null}
                {isMine && !message.is_deleted ? (
                  <button
                    type="button"
                    onClick={() => unsendMessage(conversationId, message.message_id)}
                    className="hover:text-text-secondary"
                  >
                    Unsend
                  </button>
                ) : null}
              </div>
            </li>
          );
        })}
      </ol>

      {isPending && !conversation?.is_requester ? (
        <div className="border-t border-border pt-4">
          <p className="mb-3 text-center leading-relaxed text-text-secondary">
            {other?.display_name} wants to send you messages.
          </p>
          <Button onClick={() => acceptConversation(conversationId)}>Accept</Button>
        </div>
      ) : canWrite ? (
        <form
          className="flex items-end gap-3 border-t border-border pt-4"
          onSubmit={(event) => {
            event.preventDefault();
            void send();
          }}
        >
          <textarea
            value={draft}
            rows={1}
            maxLength={2000}
            placeholder="Message"
            onChange={(event) => {
              setDraft(event.target.value);
              const now = Date.now();
              if (now - lastTyping.current > 4000) {
                lastTyping.current = now;
                void announceTyping(conversationId);
              }
            }}
            className="max-h-32 min-h-[52px] flex-1 resize-y rounded-[length:var(--radius-pill)] border border-border bg-surface px-5 py-3.5 outline-none placeholder:text-text-muted focus:border-accent"
          />
          <Button type="submit" isFullWidth={false} disabled={!draft.trim()}>
            Send
          </Button>
        </form>
      ) : null}
    </div>
  );
}
