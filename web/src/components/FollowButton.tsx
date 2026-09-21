'use client';

import { useOptimistic, useTransition } from 'react';
import { Button } from '@/components/ui/Button';
import { toggleFollow } from '@/lib/actions/stories';

export function FollowButton({
  username,
  isFollowing,
  size = 'md',
}: {
  username: string;
  isFollowing: boolean;
  size?: 'md' | 'sm';
}) {
  const [following, setOptimistic] = useOptimistic(isFollowing, (_, next: boolean) => next);
  const [, startTransition] = useTransition();

  return (
    <Button
      size={size}
      isFullWidth={size === 'md'}
      variant={following ? 'secondary' : 'primary'}
      onClick={() =>
        startTransition(async () => {
          const next = !following;
          setOptimistic(next);
          await toggleFollow(username, next);
        })
      }
    >
      {following ? 'Following' : 'Follow'}
    </Button>
  );
}
