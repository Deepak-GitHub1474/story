'use client';

import { useEffect, useRef, useState, useTransition } from 'react';
import { deleteStory, reportTarget, unpublishStory } from '@/lib/actions/stories';
import { SITE_URL } from '@/lib/config';

const REASONS = [
  ['harassment', 'Harassment'],
  ['spam', 'Spam'],
  ['self_harm', 'Someone at risk'],
  ['illegal', 'Illegal'],
  ['impersonation', 'Impersonation'],
  ['other', 'Something else'],
] as const;

export function StoryMenu({
  storyId,
  isMine,
  isPublic,
  slug,
}: {
  storyId: string;
  isMine: boolean;
  isPublic: boolean;
  slug: string | null;
}) {
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
        aria-label="Story options"
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
        <div className="absolute right-0 z-30 mt-2 w-60 overflow-hidden rounded-[length:var(--radius-md)] border border-border bg-surface shadow-lg">
          {showReasons ? (
            REASONS.map(([value, label]) => (
              <button
                key={value}
                type="button"
                onClick={() =>
                  startTransition(async () => {
                    await reportTarget('story', storyId, value);
                    setIsOpen(false);
                    setShowReasons(false);
                    setNotice('Reported. Thank you.');
                  })
                }
                className="block w-full px-4 py-3 text-left text-[length:var(--text-label)] transition-colors hover:bg-surface-raised"
              >
                {label}
              </button>
            ))
          ) : (
            <>
              {isPublic && slug ? (
                <button
                  type="button"
                  onClick={async () => {
                    await navigator.clipboard.writeText(`${SITE_URL}/s/${slug}`);
                    setIsOpen(false);
                    setNotice('Link copied.');
                  }}
                  className="block w-full px-4 py-3 text-left text-[length:var(--text-label)] transition-colors hover:bg-surface-raised"
                >
                  Copy link
                </button>
              ) : null}

              {isMine ? (
                <>
                  <a
                    href={`/compose?id=${storyId}`}
                    className="block w-full px-4 py-3 text-left text-[length:var(--text-label)] transition-colors hover:bg-surface-raised"
                  >
                    Edit
                  </a>
                  {isPublic ? (
                    <button
                      type="button"
                      onClick={() =>
                        startTransition(async () => {
                          await unpublishStory(storyId);
                          setIsOpen(false);
                        })
                      }
                      className="block w-full px-4 py-3 text-left text-[length:var(--text-label)] transition-colors hover:bg-surface-raised"
                    >
                      Move to drafts
                    </button>
                  ) : null}
                  <button
                    type="button"
                    onClick={() =>
                      startTransition(async () => {
                        if (confirm('Delete this story? This cannot be undone.')) {
                          await deleteStory(storyId);
                        }
                      })
                    }
                    className="block w-full px-4 py-3 text-left text-[length:var(--text-label)] text-danger transition-colors hover:bg-surface-raised"
                  >
                    Delete
                  </button>
                </>
              ) : (
                <button
                  type="button"
                  onClick={() => setShowReasons(true)}
                  className="block w-full px-4 py-3 text-left text-[length:var(--text-label)] transition-colors hover:bg-surface-raised"
                >
                  Report
                </button>
              )}
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
