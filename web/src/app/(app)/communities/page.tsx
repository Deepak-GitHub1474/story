import type { Metadata } from 'next';
import Link from 'next/link';
import { JoinButton } from '@/components/JoinButton';
import { Suggestions } from '@/components/Suggestions';
import { ChipLink } from '@/components/ui/Chip';
import { Carousel } from '@/components/ui/Carousel';
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
    <div className="max-w-3xl">
      <h1 className="font-editorial text-[length:var(--text-title)] font-semibold tracking-[var(--tracking-title)]">Communities</h1>
      <p className="mt-2 max-w-prose text-text-secondary">
        Rooms for one part of life. Join to read them in your feed and to write into
        them.
      </p>

      <div className="mt-8">
        <Carousel label="categories" as="div">
        <ChipLink href="/communities" isActive={!category}>
          All
        </ChipLink>
        {categories.map((item) => (
          <ChipLink
            key={item.slug}
            href={`/communities?category=${item.slug}`}
            isActive={category === item.slug}
          >
            {item.name}
          </ChipLink>
        ))}
        </Carousel>
      </div>

      {!category ? (
        <div className="mt-8">
          <Suggestions />
        </div>
      ) : null}

      <ul className="mt-6 divide-y divide-border border-y border-border">
        {communities.map((community) => (
          <li key={community.slug} className="flex items-center gap-4 py-4">
            <Link href={`/communities/${community.slug}`} className="min-w-0 flex-1">
              <p className="font-medium">{community.name}</p>
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
