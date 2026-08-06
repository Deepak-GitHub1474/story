import type { Metadata } from 'next';
import { requireUser } from '@/lib/server/guard';
import { AvatarPicker } from './AvatarPicker';

export const metadata: Metadata = { title: 'Your avatar' };

export default async function AvatarPage() {
  const user = await requireUser();
  return <AvatarPicker current={user.avatar_seed} />;
}
