'use client';

import { useOptimistic, useTransition } from 'react';
import { cn } from '@/lib/cn';
import { ShareControl } from '@/components/ShareControl';
import { toggleLike } from '@/lib/actions/stories';
import type { TStory } from '@/lib/types';

function HeartIcon({ isOn }: { isOn: boolean }) {
  return (
    <svg
      viewBox="0 0 24 24"
      aria-hidden="true"
      className={cn(
        'size-[var(--size-icon-md)] transition-transform duration-200',
        isOn ? 'scale-110' : 'group-active:scale-90',
      )}
      fill={isOn ? 'currentColor' : 'none'}
      stroke="currentColor"
      strokeWidth="1.8"
    >
      <path d="M12 20.5 4.4 13a4.6 4.6 0 0 1 6.5-6.5l1.1 1.1 1.1-1.1A4.6 4.6 0 0 1 19.6 13Z" />
    </svg>
  );
}

export function StoryActions({ story }: { story: TStory }) {
  const storyId = story.story_id;
  const isLiked = story.is_liked;
  const likes = story.counts.likes;
  const comments = story.counts.comments;
  const isPublic = story.visibility === 'public';

  const [state, setOptimistic] = useOptimistic(
    { isLiked, count: likes },
    (current, next: boolean) => ({
      isLiked: next,
      count: current.count + (next ? 1 : -1),
    }),
  );
  const [, startTransition] = useTransition();

  return (
    <div className="mt-3 flex items-center gap-5">
      <button
        type="button"
        aria-pressed={state.isLiked}
        aria-label={state.isLiked ? 'Unlike' : 'Like'}
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
        <HeartIcon isOn={state.isLiked} />
        {state.count}
      </button>

      <a
        href={`/story/${storyId}#comments`}
        className="group inline-flex items-center gap-2 text-[length:var(--text-label)] text-text-muted transition-colors hover:text-text-secondary"
      >
        <svg
          viewBox="0 0 24 24"
          aria-hidden="true"
          className="size-[var(--size-icon-md)] group-active:scale-90"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.8"
        >
          <path d="M21 11.5a8.4 8.4 0 0 1-9 8.4 9 9 0 0 1-3.9-.9L3 20.5l1.6-4.6A8.4 8.4 0 1 1 21 11.5Z" />
        </svg>
        {comments}
      </a>

      {isPublic ? <ShareControl story={story} /> : null}

    </div>
  );
}
