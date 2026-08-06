import type { Metadata } from 'next';
import { requireUser } from '@/lib/server/guard';
import { ChatList } from './ChatList';

export const metadata: Metadata = { title: 'Messages' };

export default async function ChatsPage() {
  const user = await requireUser();
  return <ChatList userId={user.user_id} />;
}
