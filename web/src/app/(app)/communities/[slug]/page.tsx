import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { JoinButton } from '@/components/JoinButton';
import { LoadMore } from '@/components/LoadMore';
import { StoryRow } from '@/components/StoryRow';
import { backendFetch } from '@/lib/server/session';
import type { TCommunity, TPage, TStory } from '@/lib/types';

type Props = { params: Promise<{ slug: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const result = await backendFetch<{ community: TCommunity }>(`/communities/${slug}`);
  return { title: result.ok ? result.value.community.name : 'Community' };
}

export default async function CommunityPage({ params }: Props) {
  const { slug } = await params;

  const [communityResult, storiesResult] = await Promise.all([
    backendFetch<{ community: TCommunity }>(`/communities/${slug}`),
    backendFetch<TPage<TStory>>(`/communities/${slug}/stories?limit=20`),
  ]);

  if (!communityResult.ok) notFound();

  const community = communityResult.value.community;
  const page = storiesResult.ok
    ? storiesResult.value
    : { items: [], next_cursor: null, has_more: false };
  const stories = page.items;

  return (
    <div className="mx-auto max-w-2xl">
      <h1 className="text-[length:var(--text-title)] font-semibold">{community.name}</h1>
      <p className="mt-2 leading-relaxed text-text-secondary">{community.description}</p>
      <p className="mt-3 text-[length:var(--text-caption)] text-text-muted">
        {community.counts.members} members · {community.counts.stories} stories
      </p>

      <div className="mt-6 max-w-xs">
        <JoinButton slug={community.slug} isMember={community.is_member} />
      </div>

      <div className="mt-10 divide-y divide-border border-t border-border">
        {stories.length === 0 ? (
          <p className="py-16 text-center text-text-muted">
            {community.is_member
              ? 'No stories here yet. Write the first one.'
              : 'No stories here yet. Join to write the first one.'}
          </p>
        ) : (
          <>
            {stories.map((story) => (
              <StoryRow key={story.story_id} story={story} />
            ))}
            <LoadMore
              initialCursor={page.next_cursor}
              hasMore={page.has_more}
              query={`source=community&slug=${slug}`}
              endMessage="That is every story in this room"
            />
          </>
        )}
      </div>
    </div>
  );
}
