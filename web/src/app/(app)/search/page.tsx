import type { Metadata } from 'next';
import Link from 'next/link';
import { Avatar } from '@/components/Avatar';
import { StoryRow } from '@/components/StoryRow';
import { backendFetch } from '@/lib/server/session';
import type { TCommunity, TStory } from '@/lib/types';
import { SearchBox } from './SearchBox';

export const metadata: Metadata = { title: 'Search' };

type TPerson = { username: string; display_name: string; avatar_seed: string };
type TResults = { users: TPerson[]; communities: TCommunity[]; stories: TStory[] };
type Props = { searchParams: Promise<{ q?: string }> };

export default async function SearchPage({ searchParams }: Props) {
  const { q = '' } = await searchParams;
  const query = q.trim();

  const result = query
    ? await backendFetch<TResults>(`/search?q=${encodeURIComponent(query)}`)
    : null;
  const data = result?.ok ? result.value : null;
  const isEmpty =
    data && !data.users.length && !data.communities.length && !data.stories.length;

  return (
    <div className="mx-auto max-w-2xl">
      <h1 className="text-[length:var(--text-title)] font-semibold">Search</h1>
      <div className="mt-6">
        <SearchBox initialQuery={query} />
      </div>

      {!query ? (
        <p className="mt-10 max-w-prose leading-relaxed text-text-secondary">
          Search accounts, communities, and public stories. Private and draft stories
          never appear here.
        </p>
      ) : isEmpty ? (
        <p className="mt-10 text-text-secondary">Nothing matched “{query}”.</p>
      ) : data ? (
        <div className="mt-10 space-y-10">
          {data.users.length > 0 ? (
            <section>
              <SectionTitle>People</SectionTitle>
              <ul className="divide-y divide-border border-y border-border">
                {data.users.map((person) => (
                  <li key={person.username}>
                    <Link
                      href={`/u/${person.username}`}
                      className="flex items-center gap-3 py-3 transition-colors hover:bg-surface"
                    >
                      <Avatar seed={person.avatar_seed} size={40} />
                      <span>
                        <span className="block font-semibold">{person.display_name}</span>
                        <span className="block text-[length:var(--text-caption)] text-text-muted">
                          @{person.username}
                        </span>
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>
            </section>
          ) : null}

          {data.communities.length > 0 ? (
            <section>
              <SectionTitle>Communities</SectionTitle>
              <ul className="divide-y divide-border border-y border-border">
                {data.communities.map((community) => (
                  <li key={community.slug}>
                    <Link
                      href={`/communities/${community.slug}`}
                      className="block py-3 transition-colors hover:bg-surface"
                    >
                      <span className="block font-semibold">{community.name}</span>
                      <span className="block text-[length:var(--text-caption)] text-text-muted">
                        {community.counts.members} members
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>
            </section>
          ) : null}

          {data.stories.length > 0 ? (
            <section>
              <SectionTitle>Stories</SectionTitle>
              <div className="divide-y divide-border border-y border-border">
                {data.stories.map((story) => (
                  <StoryRow key={story.story_id} story={story} />
                ))}
              </div>
            </section>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

function SectionTitle({ children }: { children: React.ReactNode }) {
  return (
    <h2 className="mb-3 text-[length:var(--text-caption)] font-semibold tracking-[0.12em] text-text-muted uppercase">
      {children}
    </h2>
  );
}
