'use client';

import Link from 'next/link';
import { useCallback, useEffect, useRef, useState } from 'react';
import { useRealtime } from '@/lib/chat/useRealtime';
import { Avatar } from '@/components/Avatar';
import { Button } from '@/components/ui/Button';
import { ChatUnlock } from '@/components/ChatUnlock';
import { MessageMenu } from './MessageMenu';
import { cn } from '@/lib/cn';
import { relativeTime } from '@/lib/format';
import {
  decryptMessage,
  encryptMessage,
  newConversationKey,
  pairKey,
  unwrapFromPeer,
  wrapForPeer,
} from '@/lib/chat/crypto';
import { useChatIdentity } from '@/lib/chat/useIdentity';
import type { TChatMessage, TConversation } from '@/lib/chat/types';
import {
  acceptConversation,
  announceTyping,
  markConversationRead,
  hideMessageForMe,
  peerIdentity,
  rekeyConversation,
  sendMessage,
  setReaction,
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
  const [replyTo, setReplyTo] = useState<TChatMessage | null>(null);
  const [menuFor, setMenuFor] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [needsRekey, setNeedsRekey] = useState(false);
  const [isResetting, setResetting] = useState(false);
  const cek = useRef<Uint8Array | null>(null);
  const lastTyping = useRef(0);
  const refreshRef = useRef<() => Promise<void>>(async () => {});

  const refresh = useCallback(() => refreshRef.current(), []);

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
          setNeedsRekey(true);
        }
      }
    }

    void open();
    return () => {
      cancelled = true;
    };
  }, [conversationId, identity, userId]);

  async function reset() {
    if (identity.status !== 'ready' || !conversation) return;

    setResetting(true);
    try {
      const peer = await peerIdentity(conversation.other.username);
      if (!peer) {
        setError('They have not opened Story since chat was added, so there is no key to wrap for.');
        return;
      }

      const fresh = await newConversationKey();
      const pair = pairKey(userId, peer.user_id);

      const outcome = await rekeyConversation(conversationId, {
        wrapped_cek_for_me: await wrapForPeer({
          cek: fresh,
          mine: identity.identity,
          theirPublicKey: peer.public_key,
          pair,
          recipientId: userId,
        }),
        wrapped_cek_for_them: await wrapForPeer({
          cek: fresh,
          mine: identity.identity,
          theirPublicKey: peer.public_key,
          pair,
          recipientId: peer.user_id,
        }),
        sender_public_key: identity.identity.publicKey,
      });

      if (outcome.error) {
        setError(outcome.error);
        return;
      }

      cek.current = fresh;
      setNeedsRekey(false);
      setError(null);
      await refresh();
    } finally {
      setResetting(false);
    }
  }

  useRealtime((event) => {
    if (event.conversation_id !== conversationId) return;

    if (event.type === 'unsent') {
      setMessages((current) =>
        current.filter((m) => m.message_id !== event.message_id),
      );
      return;
    }
    void refresh();
  });

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

    refreshRef.current = poll;
    void poll();
    const timer = setInterval(poll, 20000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [conversationId, decorate]);

  async function send() {
    const text = draft.trim();
    const key = cek.current;
    if (!text || !key) return;

    const pendingId = `tmp_${Date.now()}`;
    const replyingTo = replyTo?.message_id;

    setDraft('');
    setReplyTo(null);
    setMessages((current) => [
      {
        message_id: pendingId,
        conversation_id: conversationId,
        sender_id: userId,
        ciphertext: null,
        reply_to: replyingTo ?? null,
        is_deleted: false,
        reactions: [],
        created_at: new Date().toISOString(),
        text,
      },
      ...current,
    ]);

    const ciphertext = await encryptMessage(key, text, conversationId);
    const ok = await sendMessage(conversationId, ciphertext, replyingTo);

    if (!ok) {
      setMessages((current) => current.filter((m) => m.message_id !== pendingId));
      setDraft(text);
      setError('That did not send.');
      return;
    }

    await refresh();
  }

  async function react(message: TChatMessage, emoji: string) {
    const mine = message.reactions.some(
      (r) => r.emoji === emoji && r.user_id === userId,
    );
    await setReaction(conversationId, message.message_id, mine ? null : emoji);
    void refresh();
  }

  const other = conversation?.other;
  const isPending = conversation?.state === 'pending';
  const canWrite = !isPending || Boolean(conversation?.is_requester);

  return (
    <div className="flex h-[calc(100dvh-12rem)] max-w-2xl flex-col">
      <header className="sticky top-0 z-10 flex shrink-0 items-center gap-3 border-b border-border bg-bg pb-4">
        {other ? (
          <>
            <Avatar seed={other.avatar_seed} size={40} />
            <div className="min-w-0 flex-1">
              <Link href={`/u/${other.username}`} className="block font-medium">
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

      {identity.status === 'locked' ? (
        <div className="shrink-0">
          <ChatUnlock userId={userId} />
        </div>
      ) : null}

      {error ? (
        <div className="mt-3 shrink-0 rounded-[length:var(--radius-md)] bg-surface-raised px-4 py-3">
          <p className="leading-relaxed text-text-secondary">{error}</p>
          {needsRekey ? (
            <div className="mt-3">
              <Button
                variant="secondary"
                size="sm"
                isFullWidth={false}
                isLoading={isResetting}
                onClick={() => void reset()}
              >
                Reset this chat
              </Button>
              <p className="mt-2 text-[length:var(--text-caption)] text-text-muted">
                A fresh key for both of you. Everything said before it stays unreadable.
              </p>
            </div>
          ) : null}
        </div>
      ) : null}

      <ol className="flex min-h-0 flex-1 flex-col-reverse gap-2 overflow-y-auto py-6">
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
              id={`m-${message.message_id}`}
              className={cn('flex flex-col', isMine ? 'items-end' : 'items-start')}
            >
              <div
                className={cn(
                  'group/msg flex max-w-[86%] items-center gap-1',
                  isMine ? 'flex-row' : 'flex-row-reverse',
                )}
              >
                <button
                  type="button"
                  aria-label="Message options"
                  hidden={message.message_id.startsWith('tmp_')}
                  onClick={() => setMenuFor(message.message_id)}
                  className={cn(
                    'grid size-7 shrink-0 place-items-center rounded-[length:var(--radius-sm)]',
                    'text-text-muted transition-opacity duration-[var(--motion-fast)]',
                    'hover:bg-surface hover:text-text-primary',
                    'opacity-0 group-hover/msg:opacity-100 focus-visible:opacity-100',
                    '[@media(hover:none)]:opacity-100',
                  )}
                >
                  <svg viewBox="0 0 24 24" aria-hidden="true" className="size-4" fill="currentColor">
                    <circle cx="5" cy="12" r="1.6" />
                    <circle cx="12" cy="12" r="1.6" />
                    <circle cx="19" cy="12" r="1.6" />
                  </svg>
                </button>
              <button
                type="button"
                onDoubleClick={() => react(message, '❤️')}
                onContextMenu={(event) => {
                  event.preventDefault();
                  setMenuFor(message.message_id);
                }}
                className={cn(
                  'min-w-0 rounded-[length:var(--radius-lg)] px-4 py-2.5 text-left leading-relaxed',
                  isMine
                    ? 'bg-accent-strong text-accent-text'
                    : 'border border-border bg-surface',
                )}
              >
                {message.reply_to ? (
                  <span
                    onClick={(event) => {
                      event.stopPropagation();
                      document
                        .getElementById(`m-${message.reply_to}`)
                        ?.scrollIntoView({ behavior: 'smooth', block: 'center' });
                    }}
                    className={cn(
                      'mb-2 block truncate rounded-[length:var(--radius-sm)] px-2 py-1 text-[length:var(--text-caption)]',
                      isMine ? 'bg-black/15' : 'bg-surface-raised',
                    )}
                  >
                    {messages.find((m) => m.message_id === message.reply_to)?.text ??
                      'Message'}
                  </span>
                ) : null}
                {message.text ?? 'Cannot be opened in this browser'}
              </button>
              </div>

              {message.reactions.length > 0 ? (
                <span className="-mt-1 rounded-[length:var(--radius-pill)] border border-border bg-surface-raised px-1.5 text-[length:var(--text-caption)]">
                  {message.reactions.map((r) => r.emoji).join('')}
                </span>
              ) : null}

              <div className="mt-1 flex items-center gap-2 text-[length:var(--text-caption)] text-text-muted">
                <span>{relativeTime(message.created_at)}</span>
                {seen ? <span className="text-accent">Seen</span> : null}
              </div>
            </li>
          );
        })}
      </ol>

      <MessageMenu
        message={messages.find((m) => m.message_id === menuFor) ?? null}
        isMine={
          messages.find((m) => m.message_id === menuFor)?.sender_id === userId
        }
        userId={userId}
        onClose={() => setMenuFor(null)}
        onReact={(emoji) => {
          const target = messages.find((m) => m.message_id === menuFor);
          if (target) void react(target, emoji);
          setMenuFor(null);
        }}
        onReply={() => {
          const target = messages.find((m) => m.message_id === menuFor);
          if (target) setReplyTo(target);
          setMenuFor(null);
        }}
        onUnsend={() => {
          const id = menuFor;
          setMenuFor(null);
          if (!id) return;
          setMessages((current) => current.filter((m) => m.message_id !== id));
          void unsendMessage(conversationId, id);
        }}
        onHide={() => {
          const id = menuFor;
          setMenuFor(null);
          if (!id) return;
          setMessages((current) => current.filter((m) => m.message_id !== id));
          void hideMessageForMe(conversationId, id);
        }}
      />

      {isPending && !conversation?.is_requester ? (
        <div className="shrink-0 border-t border-border pt-4">
          <p className="mb-3 text-center leading-relaxed text-text-secondary">
            {other?.display_name} wants to send you messages.
          </p>
          <Button onClick={() => acceptConversation(conversationId)}>Accept</Button>
        </div>
      ) : canWrite ? (
        <form
          className="flex shrink-0 flex-col gap-2 border-t border-border pt-4"
          onSubmit={(event) => {
            event.preventDefault();
            void send();
          }}
        >
          {replyTo ? (
            <div className="flex items-center gap-2 rounded-[length:var(--radius-sm)] bg-surface-raised px-3 py-2 text-[length:var(--text-caption)]">
              <span className="w-0.5 self-stretch bg-accent" />
              <span className="flex-1 truncate text-text-secondary">
                {replyTo.text ?? 'Message'}
              </span>
              <button
                type="button"
                onClick={() => setReplyTo(null)}
                className="text-text-muted hover:text-text-primary"
              >
                Cancel
              </button>
            </div>
          ) : null}
          <div className="flex items-end gap-3">
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
            className="max-h-32 min-h-[46px] flex-1 resize-y rounded-[length:var(--radius-lg)] border border-border bg-surface px-4 py-3 outline-none placeholder:text-text-muted/70 focus:border-accent"
          />
          <Button
            type="submit"
            isFullWidth={false}
            disabled={!draft.trim() || needsRekey}
          >
            Send
          </Button>
          </div>
        </form>
      ) : null}
    </div>
  );
}
