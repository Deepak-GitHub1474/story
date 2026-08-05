import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { BlockControls } from '@/components/BlockControls';
import { Badge } from '@/components/ui/Surface';
import { requireAdmin } from '@/lib/server/guard';
import { backendFetch } from '@/lib/server/session';
import { formatDate } from '@/lib/format';
import type { TAdminUser } from '@/lib/types';

type Props = { params: Promise<{ username: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { username } = await params;
  return { title: `@${username}` };
}

export default async function AdminUserPage({ params }: Props) {
  await requireAdmin();
  const { username } = await params;

  const result = await backendFetch<{ user: TAdminUser }>(`/admin/users/${username}`);
  if (!result.ok) notFound();

  const user = result.value.user;

  return (
    <div className="max-w-2xl space-y-8">
      <header className="flex flex-wrap items-center gap-3">
        <h1 className="text-[length:var(--text-title)] font-semibold">
          @{user.username}
        </h1>
        <Badge tone={user.blocked ? 'danger' : 'success'}>
          {user.blocked ? 'Blocked' : user.status}
        </Badge>
        <Badge tone="accent">{user.role}</Badge>
      </header>

      <dl className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <Fact label="Stories" value={String(user.counts.stories ?? 0)} />
        <Fact label="Readers" value={String(user.counts.followers ?? 0)} />
        <Fact label="Following" value={String(user.counts.connections ?? 0)} />
        <Fact label="Joined" value={formatDate(user.created_at)} />
      </dl>

      {user.blocked_reason ? (
        <p className="rounded-[length:var(--radius-md)] border border-danger bg-surface px-4 py-3 text-[length:var(--text-label)]">
          Blocked because: {user.blocked_reason}
        </p>
      ) : null}

      <BlockControls username={user.username} isBlocked={user.blocked} />

      <p className="text-[length:var(--text-caption)] leading-relaxed text-text-muted">
        There is no way to read this person&rsquo;s stories, open their vault, see their
        email address, change their password, or sign in as them. Those endpoints do not
        exist for any role.
      </p>
    </div>
  );
}

function Fact({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[length:var(--radius-md)] border border-border bg-surface px-4 py-3">
      <dd className="font-semibold">{value}</dd>
      <dt className="text-[length:var(--text-caption)] text-text-muted">{label}</dt>
    </div>
  );
}
