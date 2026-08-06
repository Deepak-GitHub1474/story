import type { Metadata } from 'next';
import { backendFetch } from '@/lib/server/session';
import { InterestPicker } from '@/components/InterestPicker';

export const metadata: Metadata = { title: 'What are you into?' };

type TInterest = { slug: string; name: string; category_id: string };

export default async function OnboardingPage() {
  const result = await backendFetch<{ items: TInterest[] }>('/interests');
  return <InterestPicker interests={result.ok ? result.value.items : []} />;
}
