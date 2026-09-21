import Link from 'next/link';
import { Avatar } from '@/components/Avatar';
import { FollowButton } from '@/components/FollowButton';
import { JoinButton } from '@/components/JoinButton';
import { Carousel } from '@/components/ui/Carousel';
import { backendFetch } from '@/lib/server/session';
import type { TSuggestions } from '@/lib/types';

export async function Suggestions({
  show = 'both',
}: {
  show?: 'both' | 'rooms' | 'people';
}) {
  const result = await backendFetch<TSuggestions>('/suggestions');
  if (!result.ok) return null;

  const rooms = show === 'people' ? [] : (result.value.communities ?? []);
  const people = show === 'rooms' ? [] : (result.value.people ?? []);
  if (rooms.length === 0 && people.length === 0) return null;

  return (
    <div className="space-y-8">
      {rooms.length > 0 ? (
        <section>
          <Heading label="Rooms that fit what you follow" />
          <Carousel label="rooms">
            {rooms.map((room) => (
              <li
                key={room.slug}
                className="flex w-56 shrink-0 snap-start flex-col justify-between rounded-[length:var(--radius-lg)] border border-border bg-surface p-4 transition-colors duration-[var(--motion-fast)] hover:border-border-strong"
              >
                <Link href={`/communities/${room.slug}`} className="min-w-0">
                  <p className="truncate font-medium">{room.name}</p>
                  <p className="mt-1 line-clamp-2 text-[length:var(--text-caption)] text-text-secondary">
                    {room.description}
                  </p>
                  <p className="mt-1 text-[length:var(--text-caption)] text-text-muted">
                    {room.counts.members}{' '}
                    {room.counts.members === 1 ? 'member' : 'members'}
                  </p>
                </Link>
                <div className="mt-3">
                  <JoinButton slug={room.slug} isMember={room.is_member} />
                </div>
              </li>
            ))}
          </Carousel>
        </section>
      ) : null}

      {people.length > 0 ? (
        <section>
          <Heading label="People writing near you" />
          <Carousel label="people">
            {people.map((person) => (
              <li
                key={person.user_id}
                className="flex w-48 shrink-0 snap-start flex-col items-center gap-2 rounded-[length:var(--radius-lg)] border border-border bg-surface p-4 text-center transition-colors duration-[var(--motion-fast)] hover:border-border-strong"
              >
                <Link
                  href={person.username ? `/u/${person.username}` : '#'}
                  className="flex min-w-0 flex-col items-center gap-2"
                >
                  <Avatar seed={person.avatar_seed} size={44} />
                  <span className="w-full truncate font-medium">
                    {person.display_name}
                  </span>
                  {person.reason ? (
                    <span className="line-clamp-2 text-[length:var(--text-caption)] text-text-muted">
                      {person.reason}
                    </span>
                  ) : null}
                </Link>
                {person.username ? (
                  <FollowButton
                    username={person.username}
                    isFollowing={false}
                    size="sm"
                  />
                ) : null}
              </li>
            ))}
          </Carousel>
        </section>
      ) : null}
    </div>
  );
}

function Heading({ label }: { label: string }) {
  return (
    <h2 className="mb-3 text-[length:var(--text-caption)] font-medium tracking-[0.12em] text-text-muted uppercase">
      {label}
    </h2>
  );
}
