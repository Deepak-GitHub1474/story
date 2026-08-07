import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { Avatar } from '@/components/Avatar';
import { FollowButton } from '@/components/FollowButton';
import { MessageButton } from '@/components/MessageButton';
import { UserMenu } from '@/components/UserMenu';
import { StoryRow } from '@/components/StoryRow';
import { requireUser } from '@/lib/server/guard';
import { backendFetch } from '@/lib/server/session';
import type { TPage, TStory } from '@/lib/types';

type Props = { params: Promise<{ username: string }> };

type TProfile = {
  user_id: string;
  username: string;
  display_name: string;
  avatar_seed: string;
  bio: string | null;
  interests: string[];
  counts: Record<string, number>;
  is_following: boolean;
  is_me: boolean;
};

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { username } = await params;
  return { title: `@${username}` };
}

export default async function PublicProfilePage({ params }: Props) {
  const { username } = await params;

  const [profileResult, storiesResult, viewer] = await Promise.all([
    backendFetch<{ user: TProfile }>(`/users/${username}`),
    backendFetch<TPage<TStory>>(`/users/${username}/stories?limit=20`),
    requireUser(),
  ]);

  if (!profileResult.ok) notFound();

  const profile = profileResult.value.user;
  const stories = storiesResult.ok ? storiesResult.value.items : [];

  return (
    <div className="mx-auto max-w-2xl">
      <header className="flex flex-wrap items-center gap-6">
        <Avatar seed={profile.avatar_seed} size={80} />
        <dl className="flex flex-1 justify-around gap-6 text-center">
          <div>
            <dd className="text-[length:var(--text-heading)] font-bold">
              {profile.counts.stories ?? 0}
            </dd>
            <dt className="text-[length:var(--text-caption)] text-text-muted">Stories</dt>
          </div>
          <div>
            <dd className="text-[length:var(--text-heading)] font-bold">
              {profile.counts.followers ?? 0}
            </dd>
            <dt className="text-[length:var(--text-caption)] text-text-muted">Readers</dt>
          </div>
        </dl>
      </header>

      <div className="mt-6 flex items-start gap-3">
        <div className="min-w-0 flex-1">
        <h1 className="font-bold">{profile.display_name}</h1>
        <p className="text-[length:var(--text-caption)] text-text-muted">
          @{profile.username}
        </p>
        {profile.bio ? (
          <p className="mt-2 leading-relaxed whitespace-pre-line text-text-secondary">
            {profile.bio}
          </p>
        ) : null}
        </div>
        {profile.is_me ? null : (
          <UserMenu username={profile.username} userId={profile.user_id} />
        )}
      </div>

      {!profile.is_me ? (
        <div className="mt-6 max-w-xs">
          <div className="flex gap-3">
            <FollowButton
              username={profile.username}
              isFollowing={profile.is_following}
            />
            <MessageButton username={profile.username} viewerId={viewer.user_id} />
          </div>
        </div>
      ) : null}

      <div className="mt-10 divide-y divide-border border-t border-border">
        {stories.length === 0 ? (
          <p className="py-16 text-center text-text-muted">Nothing public yet.</p>
        ) : (
          stories.map((story) => <StoryRow key={story.story_id} story={story} />)
        )}
      </div>
    </div>
  );
}
