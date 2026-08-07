import type { Metadata } from 'next';
import { requireUser } from '@/lib/server/guard';
import { ChatThread } from './ChatThread';

export const metadata: Metadata = { title: 'Chat' };

export default async function ChatPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const user = await requireUser();

  return <ChatThread conversationId={id} userId={user.user_id} />;
}
