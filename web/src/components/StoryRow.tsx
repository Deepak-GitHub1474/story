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
    <article className="group py-8 first:pt-0 sm:py-10">
      <div className="flex items-center gap-3">
        <Link href={`/u/${story.author.username ?? ''}`} className="shrink-0">
          <Avatar seed={story.author.avatar_seed} size={28} />
        </Link>

        <p className="min-w-0 flex-1 truncate text-[length:var(--text-caption)] text-text-muted">
          <Link
            href={`/u/${story.author.username ?? ''}`}
            className="font-medium text-text-secondary underline-offset-4 hover:text-text-primary hover:underline"
          >
            {story.author.display_name}
          </Link>
          <span className="mx-1.5 text-text-muted/60">·</span>
          {story.shared ? (
            <>
              shared {story.shared.author.display_name}
              <span className="mx-1.5 text-text-muted/60">·</span>
            </>
          ) : null}
          {relativeTime(story.published_at ?? story.created_at)}
          <span className="mx-1.5 text-text-muted/60">·</span>
          {story.reading_minutes} min
          {story.community ? (
            <>
              <span className="mx-1.5 text-text-muted/60">·</span>
              <Link
                href={`/communities/${story.community.slug}`}
                className="underline-offset-4 hover:text-text-secondary hover:underline"
              >
                {story.community.name}
              </Link>
            </>
          ) : null}
        </p>

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

      <Link href={href} className="mt-4 block">
        {story.title ? (
          <h2 className="font-editorial text-[length:var(--text-heading)] leading-[1.22] font-semibold tracking-[var(--tracking-title)] text-balance transition-colors duration-[var(--motion-fast)] group-hover:text-accent sm:text-[1.6rem]">
            {story.title}
          </h2>
        ) : null}
        {story.excerpt ? (
          <p className="story-body mt-3 line-clamp-3 text-text-secondary">
            {story.excerpt}
          </p>
        ) : null}
      </Link>

      {story.images && story.images.length > 0 ? (
        <StoryImages
          images={story.images}
          ratio={story.image_ratio}
          fit={story.image_fit}
        />
      ) : null}

      {story.shared ? <SharedStoryCard shared={story.shared} /> : null}

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
    </article>
  );
}
