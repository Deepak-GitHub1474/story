import type { Metadata } from 'next';
import Link from 'next/link';
import { Avatar } from '@/components/Avatar';
import { EmptyState } from '@/components/EmptyState';
import { LoadMore } from '@/components/LoadMore';
import { StoryRow } from '@/components/StoryRow';
import { IconButton } from '@/components/ui/IconButton';
import { requireUser } from '@/lib/server/guard';
import { backendFetch } from '@/lib/server/session';
import type { TPage, TStory } from '@/lib/types';

export const metadata: Metadata = { title: 'You' };

const TABS = [
  { key: '', label: 'All' },
  { key: 'public', label: 'Public' },
  { key: 'private', label: 'Private' },
  { key: 'draft', label: 'Drafts' },
] as const;

type Props = { searchParams: Promise<{ tab?: string }> };

export default async function ProfilePage({ searchParams }: Props) {
  const { tab = '' } = await searchParams;
  const user = await requireUser();

  const query = tab ? `?visibility=${tab}&limit=20` : '?limit=20';
  const result = await backendFetch<TPage<TStory>>(`/stories/mine${query}`);
  const page = result.ok
    ? result.value
    : { items: [], next_cursor: null, has_more: false };
  const stories = page.items;
  const hasDisplayName = Boolean(
    user.display_name && user.display_name !== user.username,
  );

  return (
    <div className="max-w-2xl">
      <header className="-mr-2 flex items-center gap-2">
        <h1 className="flex-1 truncate text-[length:var(--text-heading)] font-medium">
          @{user.username}
        </h1>
        <IconButton name="edit" label="Edit profile" href="/settings/profile" />
        <IconButton name="settings" label="Settings" href="/settings" />
      </header>

      <div className="mt-4 flex items-center gap-6">
        <Link href="/settings/avatar" aria-label="Change your avatar">
          <Avatar seed={user.avatar_seed} size={72} />
        </Link>
        <dl className="flex flex-1 justify-between gap-4">
          <Stat label="Stories" value={user.counts.stories ?? 0} />
          <Stat label="Followers" value={user.counts.followers ?? 0} href="/people/followers" />
          <Stat label="Following" value={user.counts.connections ?? 0} href="/people/following" />
        </dl>
      </div>

      {hasDisplayName ? (
        <p className="mt-3 text-[length:var(--text-body)] font-medium">{user.display_name}</p>
      ) : null}

      {user.bio ? (
        <p className="mt-1 text-[length:var(--text-label)] leading-[1.5] whitespace-pre-line text-text-secondary">
          {user.bio}
        </p>
      ) : null}

      <nav className="mt-4 grid grid-cols-4">
        {TABS.map((item) => {
          const isActive = tab === item.key;
          return (
            <Link
              key={item.key}
              href={item.key ? `/profile?tab=${item.key}` : '/profile'}
              aria-current={isActive ? 'page' : undefined}
              className={
                isActive
                  ? 'border-b-2 border-accent py-3 text-center text-[length:var(--text-label)] font-medium text-text-primary'
                  : 'border-b-2 border-transparent py-3 text-center text-[length:var(--text-label)] text-text-muted hover:text-text-secondary'
              }
            >
              {item.label}
            </Link>
          );
        })}
      </nav>

      {stories.length === 0 ? (
        <EmptyState
          title={tab === 'draft' ? 'No drafts' : 'No stories yet'}
          body="Everything you write lands here, drafts included."
        />
      ) : (
        <>
          <div className="mt-2 divide-y divide-border">
            {stories.map((story) => (
              <StoryRow key={story.story_id} story={story} showVisibility isMine />
            ))}
          </div>
          <LoadMore
            initialCursor={page.next_cursor}
            hasMore={page.has_more}
            query={`source=mine${tab ? `&visibility=${tab}` : ''}`}
            isMine
            showVisibility
            endMessage="That is everything you have written"
          />
        </>
      )}
    </div>
  );
}

function Stat({
  label,
  value,
  href,
}: {
  label: string;
  value: number;
  href?: string;
}) {
  const inner = (
    <>
      <dt className="sr-only">{label}</dt>
      <dd className="numeric text-[length:var(--text-heading)] font-medium">{value}</dd>
      <p className="mt-1 text-[length:var(--text-caption)] text-text-muted">{label}</p>
    </>
  );

  return href ? (
    <Link href={href} className="text-center transition-opacity hover:opacity-80">
      {inner}
    </Link>
  ) : (
    <div className="text-center">{inner}</div>
  );
}
