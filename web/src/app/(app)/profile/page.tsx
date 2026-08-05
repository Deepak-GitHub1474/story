import type { Metadata } from 'next';
import Link from 'next/link';
import { Avatar } from '@/components/Avatar';
import { EmptyState } from '@/components/EmptyState';
import { StoryRow } from '@/components/StoryRow';
import { Button } from '@/components/ui/Button';
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
  const stories = result.ok ? result.value.items : [];

  return (
    <div className="mx-auto max-w-2xl">
      <header className="flex flex-wrap items-center gap-6">
        <Avatar seed={user.avatar_seed} size={80} />
        <dl className="flex flex-1 justify-around gap-6 text-center">
          <Stat label="Stories" value={user.counts.stories ?? 0} />
          <Stat label="Readers" value={user.counts.followers ?? 0} />
          <Stat label="Following" value={user.counts.connections ?? 0} />
        </dl>
      </header>

      <div className="mt-6">
        <h1 className="font-bold">{user.display_name}</h1>
        <p className="text-[length:var(--text-caption)] text-text-muted">
          @{user.username}
        </p>
        {user.bio ? (
          <p className="mt-2 leading-relaxed text-text-secondary">{user.bio}</p>
        ) : null}
      </div>

      <div className="mt-6 flex flex-wrap gap-2">
        <Link href="/settings/profile">
          <Button variant="secondary" size="sm" isFullWidth={false}>
            Edit profile
          </Button>
        </Link>
        <Link href="/settings">
          <Button variant="secondary" size="sm" isFullWidth={false}>
            Settings
          </Button>
        </Link>
      </div>

      <nav className="mt-8 flex gap-1 border-b border-border">
        {TABS.map((item) => {
          const isActive = tab === item.key;
          return (
            <Link
              key={item.key}
              href={item.key ? `/profile?tab=${item.key}` : '/profile'}
              aria-current={isActive ? 'page' : undefined}
              className={
                isActive
                  ? 'border-b-2 border-accent px-4 py-3 text-[length:var(--text-label)] font-semibold'
                  : 'border-b-2 border-transparent px-4 py-3 text-[length:var(--text-label)] text-text-muted hover:text-text-secondary'
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
          action={
            <Link href="/compose">
              <Button isFullWidth={false}>Write a story</Button>
            </Link>
          }
        />
      ) : (
        <div className="divide-y divide-border">
          {stories.map((story) => (
            <StoryRow key={story.story_id} story={story} showVisibility />
          ))}
        </div>
      )}
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div>
      <dt className="sr-only">{label}</dt>
      <dd className="text-[length:var(--text-heading)] font-bold">{value}</dd>
      <p className="text-[length:var(--text-caption)] text-text-muted">{label}</p>
    </div>
  );
}
