'use client';

import Link from 'next/link';
import { useState, useTransition } from 'react';
import { Avatar } from '@/components/Avatar';
import { Modal } from '@/components/ui/Modal';
import { loadLikers } from '@/lib/actions/stories';
import type { TLiker, TStoryAuthor } from '@/lib/types';

export function LikedBy({
  storyId,
  people,
  total,
}: {
  storyId: string;
  people: TStoryAuthor[];
  total: number;
}) {
  const [isOpen, setOpen] = useState(false);
  const [likers, setLikers] = useState<TLiker[]>([]);
  const [cursor, setCursor] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, startLoading] = useTransition();

  if (total === 0 || people.length === 0) return null;

  const named = people.filter((person) => person.username);
  const first = named[0];
  const others = total - 1;

  function open() {
    setOpen(true);
    if (likers.length > 0) return;
    startLoading(async () => {
      const { page, error: failed } = await loadLikers(storyId, null);
      if (!page) {
        setError(failed);
        return;
      }
      setLikers(page.items);
      setCursor(page.next_cursor);
      setHasMore(page.has_more);
    });
  }

  function more() {
    startLoading(async () => {
      const { page, error: failed } = await loadLikers(storyId, cursor);
      if (!page) {
        setError(failed);
        return;
      }
      setLikers((current) => [...current, ...page.items]);
      setCursor(page.next_cursor);
      setHasMore(page.has_more);
    });
  }

  return (
    <>
      <button
        type="button"
        onClick={open}
        className="mt-3 flex items-center gap-2 text-[length:var(--text-caption)] text-text-muted transition-colors hover:text-text-secondary"
      >
        <span className="flex -space-x-2">
          {people.slice(0, 3).map((person) => (
            <span key={person.username ?? person.avatar_seed} className="rounded-full ring-2 ring-bg">
              <Avatar seed={person.avatar_seed} size={20} />
            </span>
          ))}
        </span>
        <span>
          {first ? `Liked by ${first.display_name}` : 'Liked'}
          {others > 0 ? ` and ${others} ${others === 1 ? 'other' : 'others'}` : ''}
        </span>
      </button>

      <Modal size="sm" title="Liked by" isOpen={isOpen} onClose={() => setOpen(false)}>
        {error ? (
          <p role="alert" className="text-[length:var(--text-label)] text-danger">
            {error}
          </p>
        ) : null}

        <ul className="divide-y divide-border">
          {likers.map((person) => (
            <li key={person.user_id ?? person.liked_at}>
              <Link
                href={person.username ? `/u/${person.username}` : '#'}
                className="flex items-center gap-3 py-3"
              >
                <Avatar seed={person.avatar_seed} size={36} />
                <span className="min-w-0 flex-1">
                  <span className="block truncate font-medium">{person.display_name}</span>
                  {person.username ? (
                    <span className="block truncate text-[length:var(--text-caption)] text-text-muted">
                      @{person.username}
                    </span>
                  ) : null}
                </span>
                {person.is_me ? (
                  <span className="text-[length:var(--text-caption)] text-text-muted">You</span>
                ) : person.is_following ? (
                  <span className="text-[length:var(--text-caption)] text-text-muted">
                    Following
                  </span>
                ) : person.follows_me ? (
                  <span className="text-[length:var(--text-caption)] text-text-muted">
                    Follows you
                  </span>
                ) : null}
              </Link>
            </li>
          ))}
        </ul>

        {isLoading ? (
          <p className="py-4 text-center text-[length:var(--text-caption)] text-text-muted">
            Loading…
          </p>
        ) : hasMore ? (
          <button
            type="button"
            onClick={more}
            className="w-full py-4 text-center text-[length:var(--text-label)] text-accent hover:underline"
          >
            Show more
          </button>
        ) : null}
      </Modal>
    </>
  );
}
