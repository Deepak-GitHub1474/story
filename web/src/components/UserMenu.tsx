'use client';

import { useEffect, useRef, useState, useTransition } from 'react';
import { ReportMenu } from '@/components/ReportMenu';
import { blockUser } from '@/lib/actions/stories';

export function UserMenu({ username, userId }: { username: string; userId: string }) {
  const [isOpen, setIsOpen] = useState(false);
  const [showReasons, setShowReasons] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [, startTransition] = useTransition();
  const menu = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!isOpen) return;
    function onClick(event: MouseEvent) {
      if (!menu.current?.contains(event.target as Node)) setIsOpen(false);
    }
    document.addEventListener('mousedown', onClick);
    return () => document.removeEventListener('mousedown', onClick);
  }, [isOpen]);

  return (
    <div ref={menu} className="relative shrink-0">
      <button
        type="button"
        aria-label="Account options"
        aria-expanded={isOpen}
        onClick={() => setIsOpen((value) => !value)}
        className="rounded-[length:var(--radius-sm)] px-2 py-1 text-text-muted transition-colors hover:bg-surface hover:text-text-primary"
      >
        <svg viewBox="0 0 24 24" className="size-5" fill="currentColor" aria-hidden="true">
          <circle cx="5" cy="12" r="1.6" />
          <circle cx="12" cy="12" r="1.6" />
          <circle cx="19" cy="12" r="1.6" />
        </svg>
      </button>

      {isOpen ? (
        <div className="absolute right-0 z-30 mt-2 w-72 overflow-hidden rounded-[length:var(--radius-md)] border border-border bg-surface shadow-lg">
          {showReasons ? (
            <ReportMenu
              kind="user"
              targetId={userId}
              onDone={(message) => {
                setIsOpen(false);
                setShowReasons(false);
                setNotice(message);
              }}
            />
          ) : (
            <>
              <button
                type="button"
                onClick={() => setShowReasons(true)}
                className="block w-full px-4 py-3 text-left text-[length:var(--text-label)] transition-colors hover:bg-surface-raised"
              >
                Report this account
              </button>
              <button
                type="button"
                onClick={() =>
                  startTransition(async () => {
                    if (
                      confirm(
                        `Block ${username}? They will not see your stories and you will not see theirs.`,
                      )
                    ) {
                      await blockUser(username);
                      setIsOpen(false);
                      setNotice('Blocked.');
                    }
                  })
                }
                className="block w-full px-4 py-3 text-left text-[length:var(--text-label)] text-danger transition-colors hover:bg-surface-raised"
              >
                Block
              </button>
            </>
          )}
        </div>
      ) : null}

      {notice ? (
        <p
          role="status"
          className="absolute right-0 mt-2 rounded-[length:var(--radius-sm)] bg-surface-raised px-3 py-1.5 text-[length:var(--text-caption)] whitespace-nowrap"
        >
          {notice}
        </p>
      ) : null}
    </div>
  );
}
