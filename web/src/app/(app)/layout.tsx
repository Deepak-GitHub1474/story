import { Nav } from '@/components/Nav';
import { backendFetch } from '@/lib/server/session';
import { requireUser } from '@/lib/server/guard';

export default async function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const user = await requireUser();
  const unread = await backendFetch<{ unread: number }>('/notifications/unread-count');

  return (
    <div className="min-h-dvh">
      <Nav
        username={user.username}
        unread={unread.ok ? unread.value.unread : 0}
      />
      <main className="mx-auto w-full max-w-5xl px-4 py-8 sm:px-6">{children}</main>
    </div>
  );
}
