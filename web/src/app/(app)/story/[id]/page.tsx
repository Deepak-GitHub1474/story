import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Avatar } from '@/components/Avatar';
import { CommentThread } from '@/components/CommentThread';
import { LikeButton } from '@/components/LikeButton';
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
    <div className="mx-auto max-w-2xl">
      <div className="flex items-center gap-3">
        <Link href={`/u/${story.author.username ?? ''}`} className="shrink-0">
          <Avatar seed={story.author.avatar_seed} size={40} />
        </Link>
        <div className="min-w-0 flex-1">
          <Link
            href={`/u/${story.author.username ?? ''}`}
            className="block truncate font-semibold hover:underline"
          >
            {story.author.display_name}
          </Link>
          <p className="text-[length:var(--text-caption)] text-text-muted">
            {formatDate(story.published_at ?? story.created_at)} ·{' '}
            {story.reading_minutes} min read
            {story.community ? ` · ${story.community.name}` : ''}
          </p>
        </div>
        <StoryMenu
          storyId={story.story_id}
          isMine={isMine}
          isPublic={story.visibility === 'public'}
          slug={story.slug}
        />
      </div>

      <article className="mt-10">
        {story.title ? (
          <h1 className="text-[length:var(--text-title)] leading-tight font-bold text-balance sm:text-4xl">
            {story.title}
          </h1>
        ) : null}

        <div className="story-body mt-8 space-y-6 text-text-secondary">
          {paragraphs(story.body ?? story.excerpt).map((paragraph, index) => (
            <p key={index}>{paragraph}</p>
          ))}
        </div>
      </article>

      <div className="mt-10 flex items-center gap-6 border-y border-border py-4">
        <LikeButton
          storyId={story.story_id}
          isLiked={story.is_liked}
          count={story.counts.likes}
        />
        <span className="text-[length:var(--text-label)] text-text-muted">
          {story.counts.comments} comments
        </span>
      </div>

      <CommentThread
        storyId={story.story_id}
        comments={comments}
        currentUserId={me.user_id}
        isStoryAuthor={isMine}
      />
    </div>
  );
}
