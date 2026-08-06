import Link from 'next/link';
import { Avatar } from '@/components/Avatar';
import { StoryActions } from '@/components/StoryActions';
import { SharedStoryCard } from '@/components/SharedStoryCard';
import { StoryMenu } from '@/components/StoryMenu';
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
  const href = story.visibility === 'draft' ? `/compose?id=${story.story_id}` : `/story/${story.story_id}`;

  return (
    <article className="group py-6 first:pt-0">
      <div className="flex items-center gap-3">
        <Link href={`/u/${story.author.username ?? ''}`} className="shrink-0">
          <Avatar seed={story.author.avatar_seed} size={34} />
        </Link>
        <div className="min-w-0 flex-1">
          <Link
            href={`/u/${story.author.username ?? ''}`}
            className="block truncate text-[length:var(--text-label)] font-semibold hover:underline"
          >
            {story.author.display_name}
          </Link>
          <p className="text-[length:var(--text-caption)] text-text-muted">
            {story.shared ? `Shared ${story.shared.author.display_name}'s story · ` : ''}
            {relativeTime(story.published_at ?? story.created_at)} ·{' '}
            {story.reading_minutes} min
            {story.community ? ` · ${story.community.name}` : ''}
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

      <Link href={href} className="mt-3 block">
        {story.title ? (
          <h2 className="text-[length:var(--text-heading)] leading-snug font-bold text-balance transition-colors group-hover:text-accent">
            {story.title}
          </h2>
        ) : null}
        {story.excerpt ? (
          <p className="mt-2 line-clamp-4 leading-relaxed text-text-secondary">
            {story.excerpt}
          </p>
        ) : null}
      </Link>

      {story.shared ? <SharedStoryCard shared={story.shared} /> : null}

      {story.visibility === 'draft' || story.visibility === 'scheduled' ? null : (
        <StoryActions story={story} />
      )}
    </article>
  );
}
