import type { Metadata } from 'next';
import { InterestPicker } from '@/components/InterestPicker';
import { backendFetch } from '@/lib/server/session';

export const metadata: Metadata = { title: 'Your interests' };

type TInterest = { slug: string; name: string; category_id: string };

export default async function InterestsPage() {
  const [all, me] = await Promise.all([
    backendFetch<{ items: TInterest[] }>('/interests'),
    backendFetch<{ user: { interests?: string[] } }>('/auth/me'),
  ]);

  return (
    <InterestPicker
      interests={all.ok ? all.value.items : []}
      initial={me.ok ? (me.value.user.interests ?? []) : []}
      doneHref="/settings"
      title="Your interests"
      hasSkip={false}
    />
  );
}
