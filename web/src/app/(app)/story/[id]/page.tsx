import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Avatar } from '@/components/Avatar';
import { CommentThread } from '@/components/CommentThread';
import { LikeButton } from '@/components/LikeButton';
import { ShareControl } from '@/components/ShareControl';
import { LikedBy } from '@/components/LikedBy';
import { SharedStoryCard } from '@/components/SharedStoryCard';
import { StoryImages } from '@/components/StoryImages';
import { StoryMenu } from '@/components/StoryMenu';
import { requireUser } from '@/lib/server/guard';
import { backendFetch } from '@/lib/server/session';
import { formatDate, paragraphs } from '@/lib/format';
import type { TComment, TPage, TStory } from '@/lib/types';

type Props = { params: Promise<{ id: string }> };

export const metadata: Metadata = { title: 'Story' };

export default async function StoryPage({ params }: Props) {
  const { id } = await params;
  const me = await requireUser();

  const [storyResult, commentsResult] = await Promise.all([
    backendFetch<{ story: TStory }>(`/stories/${id}`),
    backendFetch<TPage<TComment>>(`/stories/${id}/comments?limit=50`),
  ]);

  if (!storyResult.ok) notFound();

  const story = storyResult.value.story;
  const comments = commentsResult.ok ? commentsResult.value.items : [];
  const isMine = story.author.user_id === me.user_id;

  return (
    <div className="max-w-[42rem]">
      <article>
        <p className="text-[length:var(--text-caption)] tracking-[var(--tracking-eyebrow)] text-text-muted uppercase">
          {story.community ? story.community.name : 'Unfiled'}
        </p>

        {story.title ? (
          <h1 className="font-editorial mt-5 text-[length:var(--text-title)] leading-[1.08] font-semibold tracking-[var(--tracking-title)] text-balance sm:text-[2.6rem]">
            {story.title}
          </h1>
        ) : null}

        <div className="mt-8 flex items-center gap-3 border-y border-border py-4">
          <Link href={`/u/${story.author.username ?? ''}`} className="shrink-0">
            <Avatar seed={story.author.avatar_seed} size={36} />
          </Link>
          <div className="min-w-0 flex-1">
            <Link
              href={`/u/${story.author.username ?? ''}`}
              className="block truncate text-[length:var(--text-label)] font-medium underline-offset-4 hover:underline"
            >
              {story.author.display_name}
            </Link>
            <p className="truncate text-[length:var(--text-caption)] text-text-muted">
              {story.shared
                ? `Shared ${story.shared.author.display_name}'s story · `
                : ''}
              {formatDate(story.published_at ?? story.created_at)} ·{' '}
              {story.reading_minutes} min read
            </p>
          </div>
          <StoryMenu
            storyId={story.story_id}
            isMine={isMine}
            isPublic={story.visibility === 'public'}
            slug={story.slug}
          />
        </div>

        {story.images && story.images.length > 0 ? (
          <StoryImages
            images={story.images}
            ratio={story.image_ratio}
            fit={story.image_fit}
          />
        ) : null}

        <div className="story-body mt-10 max-w-[var(--size-measure)] text-text-primary/92">
          {paragraphs(story.body ?? story.excerpt).map((paragraph, index) => (
            <p key={index}>{paragraph}</p>
          ))}
        </div>

        {story.shared ? <SharedStoryCard shared={story.shared} /> : null}
      </article>

      <div className="mt-12 flex flex-wrap items-center gap-x-7 gap-y-3 border-y border-border py-4">
        <LikeButton
          storyId={story.story_id}
          isLiked={story.is_liked}
          count={story.counts.likes}
        />
        <span className="text-[length:var(--text-label)] text-text-muted">
          {story.counts.comments} comments
        </span>
        {story.visibility === 'public' ? <ShareControl story={story} /> : null}
      </div>

      <LikedBy
        storyId={story.story_id}
        people={story.liked_by ?? []}
        total={story.counts.likes}
      />

      <CommentThread
        storyId={story.story_id}
        comments={comments}
        currentUserId={me.user_id}
        isStoryAuthor={isMine}
      />
    </div>
  );
}
