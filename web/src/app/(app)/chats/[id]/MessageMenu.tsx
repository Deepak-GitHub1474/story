'use client';

import { useState } from 'react';
import { Modal } from '@/components/ui/Modal';
import { cn } from '@/lib/cn';
import type { TChatMessage } from '@/lib/chat/types';

const QUICK_REACTIONS = ['❤️', '😂', '😮', '😢', '🙏', '🔥'];

function Action({
  label,
  hint,
  isDanger = false,
  onClick,
}: {
  label: string;
  hint?: string;
  isDanger?: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        'flex w-full flex-col items-start gap-0.5 rounded-[length:var(--radius-md)] px-3 py-2.5 text-left',
        'transition-colors duration-[var(--motion-fast)] hover:bg-surface',
        isDanger ? 'text-danger' : 'text-text-primary',
      )}
    >
      <span className="text-[length:var(--text-label)] font-medium">{label}</span>
      {hint ? (
        <span className="text-[length:var(--text-caption)] text-text-muted">{hint}</span>
      ) : null}
    </button>
  );
}

export function MessageMenu({
  message,
  isMine,
  userId,
  onClose,
  onReact,
  onReply,
  onUnsend,
  onHide,
}: {
  message: TChatMessage | null;
  isMine: boolean;
  userId: string;
  onClose: () => void;
  onReact: (emoji: string) => void;
  onReply: () => void;
  onUnsend: () => void;
  onHide: () => void;
}) {
  const [copied, setCopied] = useState(false);

  return (
    <Modal
      title="Message"
      isOpen={message !== null}
      onClose={() => {
        setCopied(false);
        onClose();
      }}
      size="sm"
    >
      {message ? (
        <div className="flex flex-col gap-5">
          <p className="line-clamp-3 rounded-[length:var(--radius-md)] border border-border bg-surface px-3 py-2 leading-relaxed text-text-secondary">
            {message.text ?? 'Cannot be opened in this browser'}
          </p>

          <div className="flex flex-wrap justify-between gap-1">
            {QUICK_REACTIONS.map((emoji) => {
              const isOn = message.reactions.some(
                (r) => r.emoji === emoji && r.user_id === userId,
              );
              return (
                <button
                  key={emoji}
                  type="button"
                  aria-pressed={isOn}
                  onClick={() => onReact(emoji)}
                  className={cn(
                    'grid size-11 place-items-center rounded-[length:var(--radius-md)] text-xl',
                    'transition-transform duration-[var(--motion-fast)] hover:scale-110',
                    isOn ? 'bg-accent-soft ring-1 ring-accent' : 'hover:bg-surface',
                  )}
                >
                  {emoji}
                </button>
              );
            })}
          </div>

          <div className="-mx-1 flex flex-col border-t border-border pt-2">
            <Action label="Reply" hint="Quote this in your next message" onClick={onReply} />
            <Action
              label={copied ? 'Copied' : 'Copy text'}
              onClick={() => {
                void navigator.clipboard?.writeText(message.text ?? '');
                setCopied(true);
              }}
            />
            <Action
              label="Delete for me"
              hint="Hides it from your side only. They keep their copy."
              onClick={onHide}
            />
            {isMine ? (
              <Action
                label="Unsend"
                hint="Removes it for both of you. This cannot be undone."
                isDanger
                onClick={onUnsend}
              />
            ) : null}
          </div>
        </div>
      ) : null}
    </Modal>
  );
}
