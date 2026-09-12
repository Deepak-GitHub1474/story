import type { Metadata } from 'next';
import { requireAdmin } from '@/lib/server/guard';
import { backendFetch } from '@/lib/server/session';
import { relativeTime } from '@/lib/format';
import { PageHeader } from '@/components/ui/PageHeader';
import type { TAuditEntry } from '@/lib/types';

export const metadata: Metadata = { title: 'Audit' };

export default async function AuditPage() {
  await requireAdmin();

  const result = await backendFetch<{ items: TAuditEntry[] }>('/admin/audit');
  const entries = result.ok ? result.value.items : [];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Audit log"
        description="Append-only and hash-chained. Nothing here can be edited or deleted, by any role, through any endpoint."
      />

      {entries.length === 0 ? (
        <p className="rounded-[length:var(--radius-lg)] border border-border bg-surface px-6 py-16 text-center text-[length:var(--text-label)] text-text-muted">
          No staff actions recorded yet.
        </p>
      ) : (
        <div className="overflow-x-auto rounded-[length:var(--radius-lg)] border border-border">
          <table className="w-full min-w-[640px] text-left">
            <thead className="bg-surface text-[length:var(--text-micro)] tracking-[var(--tracking-eyebrow)] text-text-muted uppercase">
              <tr>
                <th className="px-4 py-2.5 font-medium whitespace-nowrap">When</th>
                <th className="px-4 py-2.5 font-medium whitespace-nowrap">Who</th>
                <th className="px-4 py-2.5 font-medium whitespace-nowrap">Action</th>
                <th className="px-4 py-2.5 font-medium whitespace-nowrap">Target</th>
                <th className="px-4 py-2.5 font-medium whitespace-nowrap">Outcome</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {entries.map((entry) => (
                <tr key={entry.entry_id} className="bg-bg text-[length:var(--text-label)] transition-colors hover:bg-surface">
                  <td className="px-4 py-2.5 whitespace-nowrap text-text-muted">
                    {relativeTime(entry.occurred_at)}
                  </td>
                  <td className="numeric px-4 py-2.5 whitespace-nowrap">
                    @{entry.actor.username ?? '—'}
                    <span className="ml-1 text-text-muted">({entry.actor.role})</span>
                  </td>
                  <td className="numeric px-4 py-2.5 text-[length:var(--text-caption)] whitespace-nowrap">
                    {entry.action}
                  </td>
                  <td className="numeric px-4 py-2.5 text-[length:var(--text-caption)] text-text-muted">
                    {entry.target.kind}:{(entry.target.id ?? '').slice(0, 12)}
                  </td>
                  <td className="px-4 py-2.5">
                    <span
                      className={
                        entry.outcome === 'success' ? 'text-success' : 'text-danger'
                      }
                    >
                      {entry.outcome}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
