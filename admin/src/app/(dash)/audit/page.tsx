import type { Metadata } from 'next';
import { requireAdmin } from '@/lib/server/guard';
import { backendFetch } from '@/lib/server/session';
import { relativeTime } from '@/lib/format';
import type { TAuditEntry } from '@/lib/types';

export const metadata: Metadata = { title: 'Audit' };

export default async function AuditPage() {
  await requireAdmin();

  const result = await backendFetch<{ items: TAuditEntry[] }>('/admin/audit');
  const entries = result.ok ? result.value.items : [];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-[length:var(--text-title)] font-medium">Audit log</h1>
        <p className="mt-1 text-[length:var(--text-label)] leading-relaxed text-text-secondary">
          Append-only and hash-chained. Nothing here can be edited or deleted, by any
          role, through any endpoint.
        </p>
      </div>

      {entries.length === 0 ? (
        <p className="rounded-[length:var(--radius-md)] border border-border bg-surface px-6 py-16 text-center text-text-secondary">
          No staff actions recorded yet.
        </p>
      ) : (
        <div className="overflow-x-auto rounded-[length:var(--radius-md)] border border-border">
          <table className="w-full min-w-[640px] text-left">
            <thead className="bg-surface text-[length:var(--text-caption)] tracking-wide text-text-muted uppercase">
              <tr>
                <th className="px-4 py-3 font-medium">When</th>
                <th className="px-4 py-3 font-medium">Who</th>
                <th className="px-4 py-3 font-medium">Action</th>
                <th className="px-4 py-3 font-medium">Target</th>
                <th className="px-4 py-3 font-medium">Outcome</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {entries.map((entry) => (
                <tr key={entry.entry_id} className="bg-bg text-[length:var(--text-label)]">
                  <td className="px-4 py-3 whitespace-nowrap text-text-muted">
                    {relativeTime(entry.occurred_at)}
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap">
                    @{entry.actor.username ?? '—'}
                    <span className="ml-1 text-text-muted">({entry.actor.role})</span>
                  </td>
                  <td className="px-4 py-3 font-mono text-[length:var(--text-caption)]">
                    {entry.action}
                  </td>
                  <td className="px-4 py-3 text-text-muted">
                    {entry.target.kind}:{(entry.target.id ?? '').slice(0, 12)}
                  </td>
                  <td className="px-4 py-3">
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
