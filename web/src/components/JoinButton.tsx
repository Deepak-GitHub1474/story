'use client';

import { useOptimistic, useTransition } from 'react';
import { Button } from '@/components/ui/Button';
import { toggleMembership } from '@/lib/actions/stories';

export function JoinButton({ slug, isMember }: { slug: string; isMember: boolean }) {
  const [joined, setOptimistic] = useOptimistic(isMember, (_, next: boolean) => next);
  const [, startTransition] = useTransition();

  return (
    <Button
      size="sm"
      isFullWidth={false}
      variant={joined ? 'secondary' : 'primary'}
      onClick={() =>
        startTransition(async () => {
          const next = !joined;
          setOptimistic(next);
          await toggleMembership(slug, next);
        })
      }
    >
      {joined ? 'Joined' : 'Join'}
    </Button>
  );
}
