import Link from 'next/link';
import { Avatar } from '@/components/Avatar';
import { StoryActions } from '@/components/StoryActions';
import { SharedStoryCard } from '@/components/SharedStoryCard';
import { StoryImages } from '@/components/StoryImages';
import { StoryMenu } from '@/components/StoryMenu';
import { LikedBy } from '@/components/LikedBy';
import { Badge } from '@/components/ui/Surface';
import { relativeTime } from '@/lib/format';
import type { TStory } from '@/lib/types';

export function StoryRow({
  story,
  showVisibility = false,
  isMine = false,
}: {
  story: TStory;
  showVisibility?: boolean;
  isMine?: boolean;
}) {
  const href =
    story.visibility === 'draft'
      ? `/compose?id=${story.story_id}`
      : `/story/${story.story_id}`;
  const isUnpublished =
    story.visibility === 'draft' || story.visibility === 'scheduled';

  return (
    <article className="py-6 first:pt-0 sm:py-8">
      <div className="flex items-center gap-3">
        <Link href={`/u/${story.author.username ?? ''}`} className="shrink-0">
          <Avatar seed={story.author.avatar_seed} size={38} />
        </Link>

        <div className="min-w-0 flex-1">
          <Link
            href={`/u/${story.author.username ?? ''}`}
            className="block truncate text-[length:var(--text-body)] font-medium text-text-primary"
          >
            {story.author.display_name}
          </Link>
          <p className="truncate text-[length:var(--text-caption)] text-text-muted">
            {story.shared ? `Shared ${story.shared.author.display_name}'s story · ` : ''}
            {relativeTime(story.published_at ?? story.created_at)}
            <span className="mx-1.5 text-text-muted/60">·</span>
            {story.reading_minutes} min
            {story.community ? (
              <>
                <span className="mx-1.5 text-text-muted/60">·</span>
                <Link
                  href={`/communities/${story.community.slug}`}
                  className="underline-offset-4 hover:underline"
                >
                  {story.community.name}
                </Link>
              </>
            ) : null}
          </p>
        </div>

        {showVisibility ? (
          <Badge
            tone={
              story.visibility === 'public'
                ? 'success'
                : story.visibility === 'scheduled'
                  ? 'accent'
                  : 'neutral'
            }
          >
            {story.visibility}
          </Badge>
        ) : null}

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

      {isUnpublished ? null : (
        <>
          <StoryActions story={story} />
          <LikedBy
            storyId={story.story_id}
            people={story.liked_by ?? []}
            total={story.counts.likes}
          />
        </>
      )}

      {story.title || story.excerpt ? (
        <Link
          href={href}
          className="mt-2 block text-[length:var(--text-label)] leading-[1.5]"
        >
          <span className="font-medium text-text-primary">
            {story.author.display_name}
          </span>
          {'  '}
          {story.title ? (
            <>
              <span className="font-medium text-text-primary">{story.title}</span>
              <br />
            </>
          ) : null}
          <span className="line-clamp-3 text-text-secondary">{story.excerpt}</span>
        </Link>
      ) : null}

      {story.shared ? <SharedStoryCard shared={story.shared} /> : null}
    </article>
  );
}
