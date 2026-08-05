import Link from 'next/link';
import { Avatar } from '@/components/Avatar';
import { Badge } from '@/components/ui/Surface';
import { relativeTime } from '@/lib/format';
import type { TStory } from '@/lib/types';

export function StoryRow({
  story,
  showVisibility = false,
}: {
  story: TStory;
  showVisibility?: boolean;
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
      </div>

      <Link href={href} className="mt-3 block">
        {story.title ? (
          <h2 className="text-[length:var(--text-heading)] leading-snug font-bold text-balance transition-colors group-hover:text-accent">
            {story.title}
          </h2>
        ) : null}
        <p className="mt-2 line-clamp-4 leading-relaxed text-text-secondary">
          {story.excerpt}
        </p>
      </Link>

      <p className="mt-3 text-[length:var(--text-caption)] font-semibold text-text-muted">
        {story.counts.likes} {story.counts.likes === 1 ? 'like' : 'likes'} ·{' '}
        {story.counts.comments}{' '}
        {story.counts.comments === 1 ? 'comment' : 'comments'}
      </p>
    </article>
  );
}
