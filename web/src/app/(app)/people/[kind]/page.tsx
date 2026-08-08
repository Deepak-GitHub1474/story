import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Avatar } from '@/components/Avatar';
import { EmptyState } from '@/components/EmptyState';
import { UnblockButton } from '@/components/UnblockButton';
import { backendFetch } from '@/lib/server/session';

const KINDS = {
  following: {
    path: '/connections/following',
    title: 'Following',
    empty: 'When you follow someone, their stories move to the top of yours.',
  },
  followers: {
    path: '/connections/followers',
    title: 'Readers',
    empty: 'People who follow you appear here.',
  },
  blocked: {
    path: '/connections/blocked',
    title: 'Blocked accounts',
    empty: 'Blocked accounts cannot see you and you cannot see them.',
  },
} as const;

type Kind = keyof typeof KINDS;
type Props = { params: Promise<{ kind: string }> };
type TPerson = {
  username: string;
  display_name: string;
  avatar_seed: string;
  bio: string | null;
};

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { kind } = await params;
  return { title: KINDS[kind as Kind]?.title ?? 'People' };
}

export default async function PeoplePage({ params }: Props) {
  const { kind } = await params;
  const config = KINDS[kind as Kind];
  if (!config) notFound();

  const result = await backendFetch<{ items: TPerson[] }>(config.path);
  const people = result.ok ? result.value.items : [];

  return (
    <div className="mx-auto max-w-2xl">
      <h1 className="text-[length:var(--text-title)] font-medium">{config.title}</h1>

      {people.length === 0 ? (
        <EmptyState title="Nobody here yet" body={config.empty} />
      ) : (
        <ul className="mt-8 divide-y divide-border border-y border-border">
          {people.map((person) => (
            <li key={person.username} className="flex items-center gap-3 py-3">
              <Link
                href={`/u/${person.username}`}
                className="flex min-w-0 flex-1 items-center gap-3"
              >
                <Avatar seed={person.avatar_seed} size={40} />
                <span className="min-w-0">
                  <span className="block truncate font-medium">
                    {person.display_name}
                  </span>
                  <span className="block text-[length:var(--text-caption)] text-text-muted">
                    @{person.username}
                  </span>
                </span>
              </Link>
              {kind === 'blocked' ? <UnblockButton username={person.username} /> : null}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
