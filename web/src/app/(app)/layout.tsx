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
    <div data-surface="app" className="min-h-dvh">
      <Nav
        username={user.username}
        avatarSeed={user.avatar_seed}
        unread={unread.ok ? unread.value.unread : 0}
      />
      <main className="mx-auto w-full max-w-5xl px-6 pt-4 pb-24 sm:px-8 sm:pt-12 sm:pb-20">
        {children}
      </main>
    </div>
  );
}
