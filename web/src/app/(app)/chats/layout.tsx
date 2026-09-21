import { requireUser } from '@/lib/server/guard';
import { ChatList } from './ChatList';
import { ChatShell } from './ChatShell';

export default async function ChatsLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const user = await requireUser();

  return (
    <ChatShell list={<ChatList userId={user.user_id} />}>{children}</ChatShell>
  );
}
