import type { Metadata } from 'next';
import { requireUser } from '@/lib/server/guard';
import { NewChat } from './NewChat';

export const metadata: Metadata = { title: 'New message' };

export default async function NewChatPage() {
  const user = await requireUser();
  return <NewChat viewerId={user.user_id} />;
}
