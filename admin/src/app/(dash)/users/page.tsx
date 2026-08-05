import type { Metadata } from 'next';
import { requireAdmin } from '@/lib/server/guard';
import { UserLookup } from './UserLookup';

export const metadata: Metadata = { title: 'Accounts' };

export default async function UsersPage() {
  await requireAdmin();

  return (
    <div className="max-w-lg">
      <h1 className="text-[length:var(--text-title)] font-semibold">Accounts</h1>
      <p className="mt-1 text-[length:var(--text-label)] leading-relaxed text-text-secondary">
        Look an account up by username. Metadata only — no story content, no vault, no
        email address. Those are not available to any role.
      </p>
      <div className="mt-8">
        <UserLookup />
      </div>
    </div>
  );
}
