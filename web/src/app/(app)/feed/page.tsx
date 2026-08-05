import type { Metadata } from 'next';
import Link from 'next/link';
import { EmptyState } from '@/components/EmptyState';
import { StoryRow } from '@/components/StoryRow';
import { Button } from '@/components/ui/Button';
import { backendFetch } from '@/lib/server/session';
import type { TPage, TStory } from '@/lib/types';
import { LoadMore } from '@/components/LoadMore';

export const metadata: Metadata = { title: 'Stories' };

export default async function FeedPage() {
  const result = await backendFetch<TPage<TStory>>('/stories/feed?limit=20');

  if (!result.ok) {
    return (
      <EmptyState
        title="Could not load your stories"
        body={result.message}
        action={
          <Link href="/feed">
            <Button isFullWidth={false} variant="secondary">
              Try again
            </Button>
          </Link>
        }
      />
    );
  }

  const page = result.value;

  if (page.items.length === 0) {
    return (
      <EmptyState
        title="Nothing here yet"
        body="Follow someone or join a community, and their stories arrive first. Or write the first one — nobody will know it was you."
        action={
          <Link href="/compose">
            <Button isFullWidth={false}>Write a story</Button>
          </Link>
        }
      />
    );
  }

  return (
    <div className="mx-auto max-w-2xl">
      <h1 className="sr-only">Stories</h1>
      <div className="divide-y divide-border">
        {page.items.map((story) => (
          <StoryRow key={story.story_id} story={story} />
        ))}
      </div>
      <LoadMore
        initialCursor={page.next_cursor}
        hasMore={page.has_more}
        query="source=feed"
      />
    </div>
  );
}
