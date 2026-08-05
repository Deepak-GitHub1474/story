import type { Metadata } from 'next';
import Link from 'next/link';
import { JoinButton } from '@/components/JoinButton';
import { backendFetch } from '@/lib/server/session';
import type { TCommunity } from '@/lib/types';

export const metadata: Metadata = { title: 'Communities' };

type TCategory = { slug: string; name: string; tone: string; description: string };
type Props = { searchParams: Promise<{ category?: string }> };

export default async function CommunitiesPage({ searchParams }: Props) {
  const { category } = await searchParams;

  const [categoriesResult, communitiesResult] = await Promise.all([
    backendFetch<{ items: TCategory[] }>('/communities/categories'),
    backendFetch<{ items: TCommunity[] }>(
      category ? `/communities?category=${encodeURIComponent(category)}` : '/communities',
    ),
  ]);

  const categories = categoriesResult.ok ? categoriesResult.value.items : [];
  const communities = communitiesResult.ok ? communitiesResult.value.items : [];

  return (
    <div className="mx-auto max-w-3xl">
      <h1 className="text-[length:var(--text-title)] font-semibold">Communities</h1>
      <p className="mt-2 max-w-prose text-text-secondary">
        Rooms for one part of life. Join to read them in your feed and to write into
        them.
      </p>

      <nav className="mt-6 -mx-4 flex gap-2 overflow-x-auto px-4 pb-2">
        <CategoryChip href="/communities" label="All" isActive={!category} />
        {categories.map((item) => (
          <CategoryChip
            key={item.slug}
            href={`/communities?category=${item.slug}`}
            label={item.name}
            isActive={category === item.slug}
          />
        ))}
      </nav>

      <ul className="mt-6 divide-y divide-border border-y border-border">
        {communities.map((community) => (
          <li key={community.slug} className="flex items-center gap-4 py-4">
            <Link href={`/communities/${community.slug}`} className="min-w-0 flex-1">
              <p className="font-semibold">{community.name}</p>
              <p className="truncate text-[length:var(--text-caption)] text-text-secondary">
                {community.description}
              </p>
              <p className="text-[length:var(--text-caption)] text-text-muted">
                {community.counts.members}{' '}
                {community.counts.members === 1 ? 'member' : 'members'}
              </p>
            </Link>
            <JoinButton slug={community.slug} isMember={community.is_member} />
          </li>
        ))}
      </ul>
    </div>
  );
}

function CategoryChip({
  href,
  label,
  isActive,
}: {
  href: string;
  label: string;
  isActive: boolean;
}) {
  return (
    <Link
      href={href}
      className={
        isActive
          ? 'shrink-0 rounded-[length:var(--radius-pill)] border border-accent bg-accent px-4 py-2 text-[length:var(--text-label)] font-semibold text-accent-text'
          : 'shrink-0 rounded-[length:var(--radius-pill)] border border-border px-4 py-2 text-[length:var(--text-label)] text-text-secondary transition-colors hover:border-text-muted'
      }
    >
      {label}
    </Link>
  );
}
