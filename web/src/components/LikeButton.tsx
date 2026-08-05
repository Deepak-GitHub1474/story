'use client';

import { useOptimistic, useTransition } from 'react';
import { cn } from '@/lib/cn';
import { toggleLike } from '@/lib/actions/stories';

export function LikeButton({
  storyId,
  isLiked,
  count,
}: {
  storyId: string;
  isLiked: boolean;
  count: number;
}) {
  const [state, setOptimistic] = useOptimistic(
    { isLiked, count },
    (current, next: boolean) => ({
      isLiked: next,
      count: current.count + (next ? 1 : -1),
    }),
  );
  const [, startTransition] = useTransition();

  return (
    <button
      type="button"
      aria-pressed={state.isLiked}
      onClick={() =>
        startTransition(async () => {
          const next = !state.isLiked;
          setOptimistic(next);
          await toggleLike(storyId, next);
        })
      }
      className={cn(
        'group inline-flex items-center gap-2 text-[length:var(--text-label)] transition-colors',
        state.isLiked ? 'text-danger' : 'text-text-muted hover:text-text-secondary',
      )}
    >
      <svg
        viewBox="0 0 24 24"
        aria-hidden="true"
        className={cn(
          'size-[var(--size-icon-md)] transition-transform duration-200',
          state.isLiked ? 'scale-110' : 'group-active:scale-90',
        )}
        fill={state.isLiked ? 'currentColor' : 'none'}
        stroke="currentColor"
        strokeWidth="1.8"
      >
        <path d="M12 20.5 4.4 13a4.6 4.6 0 0 1 6.5-6.5l1.1 1.1 1.1-1.1A4.6 4.6 0 0 1 19.6 13Z" />
      </svg>
      {state.count}
    </button>
  );
}
