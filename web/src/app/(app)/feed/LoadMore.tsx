'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { StoryRow } from '@/components/StoryRow';
import { Skeleton } from '@/components/ui/Surface';
import type { TPage, TStory } from '@/lib/types';

export function LoadMore({
  initialCursor,
  hasMore,
}: {
  initialCursor: string | null;
  hasMore: boolean;
}) {
  const [stories, setStories] = useState<TStory[]>([]);
  const [cursor, setCursor] = useState(initialCursor);
  const [more, setMore] = useState(hasMore);
  const [isLoading, setIsLoading] = useState(false);
  const sentinel = useRef<HTMLDivElement>(null);

  const load = useCallback(async () => {
    if (!more || !cursor || isLoading) return;
    setIsLoading(true);

    const response = await fetch(`/api/feed?cursor=${encodeURIComponent(cursor)}`);
    const page = (await response.json()) as TPage<TStory> | null;

    if (page) {
      setStories((current) => [...current, ...page.items]);
      setCursor(page.next_cursor);
      setMore(page.has_more);
    } else {
      setMore(false);
    }
    setIsLoading(false);
  }, [cursor, more, isLoading]);

  useEffect(() => {
    const node = sentinel.current;
    if (!node || !more) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) void load();
      },
      { rootMargin: '600px' },
    );
    observer.observe(node);
    return () => observer.disconnect();
  }, [load, more]);

  return (
    <>
      {stories.length > 0 ? (
        <div className="divide-y divide-border border-t border-border">
          {stories.map((story) => (
            <StoryRow key={story.story_id} story={story} />
          ))}
        </div>
      ) : null}

      {more ? (
        <div ref={sentinel} className="space-y-4 border-t border-border py-6">
          <Skeleton className="h-4 w-40" />
          <Skeleton className="h-4 w-full" />
          <Skeleton className="h-4 w-3/4" />
        </div>
      ) : (
        <p className="border-t border-border py-10 text-center text-[length:var(--text-caption)] text-text-muted">
          You are all caught up
        </p>
      )}
    </>
  );
}
