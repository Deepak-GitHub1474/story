import type { Metadata } from 'next';
import { backendFetch } from '@/lib/server/session';
import type { TCommunity, TStory } from '@/lib/types';
import { Composer } from './Composer';

export const metadata: Metadata = { title: 'Write' };

type Props = { searchParams: Promise<{ id?: string }> };

export default async function ComposePage({ searchParams }: Props) {
  const { id } = await searchParams;

  const [storyResult, communitiesResult] = await Promise.all([
    id ? backendFetch<{ story: TStory }>(`/stories/${id}`) : null,
    backendFetch<{ items: TCommunity[] }>('/communities/me'),
  ]);

  return (
    <Composer
      story={storyResult?.ok ? storyResult.value.story : null}
      communities={communitiesResult.ok ? communitiesResult.value.items : []}
    />
  );
}
