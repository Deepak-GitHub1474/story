import Link from 'next/link';
import { Avatar } from '@/components/Avatar';
import type { TSharedStory } from '@/lib/types';

export function SharedStoryCard({
  shared,
  isStatic = false,
}: {
  shared: TSharedStory;
  isStatic?: boolean;
}) {
  const inner = (
    <>
      <div className="flex items-center gap-2">
        <Avatar seed={shared.author.avatar_seed} size={22} />
        <span className="truncate text-[length:var(--text-caption)] font-semibold text-text-secondary">
          {shared.author.display_name}
        </span>
      </div>
      {shared.title ? (
        <p className="mt-2 line-clamp-2 text-[length:var(--text-label)] leading-snug font-semibold">
          {shared.title}
        </p>
      ) : null}
      <p className="mt-1 line-clamp-3 text-[length:var(--text-label)] leading-relaxed text-text-muted">
        {shared.excerpt}
      </p>
    </>
  );

  const className =
    'mt-3 block rounded-[length:var(--radius-md)] border border-border p-4 transition-colors';

  if (isStatic) return <div className={className}>{inner}</div>;

  return (
    <Link href={`/story/${shared.story_id}`} className={`${className} hover:border-text-muted`}>
      {inner}
    </Link>
  );
}
