import type { Metadata } from 'next';
import { ReportCard } from '@/components/ReportCard';
import { backendFetch } from '@/lib/server/session';
import { currentStaff } from '@/lib/server/guard';
import type { TReport, TStats } from '@/lib/types';

export const metadata: Metadata = { title: 'Queue' };

export default async function QueuePage() {
  const staff = await currentStaff();
  const isAdmin = staff?.role !== 'moderator';

  const [reportsResult, statsResult] = await Promise.all([
    backendFetch<{ items: TReport[] }>('/admin/reports'),
    isAdmin ? backendFetch<TStats>('/admin/stats') : null,
  ]);

  const reports = reportsResult.ok ? reportsResult.value.items : [];
  const stats = statsResult?.ok ? statsResult.value : null;

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-[length:var(--text-title)] font-semibold">Report queue</h1>
        <p className="mt-1 text-[length:var(--text-label)] text-text-secondary">
          Oldest first. Actioning removes the content; dismissing leaves it.
        </p>
      </div>

      {stats ? (
        <dl className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
          <Stat label="Open reports" value={stats.open_reports} isAlert={stats.open_reports > 0} />
          <Stat label="Accounts" value={stats.users} />
          <Stat label="Blocked" value={stats.blocked_users} />
          <Stat label="Stories" value={stats.stories} />
          <Stat label="Comments" value={stats.comments} />
          <Stat label="Communities" value={stats.communities} />
        </dl>
      ) : null}

      {reports.length === 0 ? (
        <p className="rounded-[length:var(--radius-md)] border border-border bg-surface px-6 py-16 text-center text-text-secondary">
          Nothing waiting. The queue is empty.
        </p>
      ) : (
        <ul className="space-y-3">
          {reports.map((report) => (
            <li key={report.report_id}>
              <ReportCard report={report} />
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function Stat({
  label,
  value,
  isAlert = false,
}: {
  label: string;
  value: number;
  isAlert?: boolean;
}) {
  return (
    <div className="rounded-[length:var(--radius-md)] border border-border bg-surface px-4 py-3">
      <dd
        className={
          isAlert
            ? 'text-[length:var(--text-title)] font-bold text-danger'
            : 'text-[length:var(--text-title)] font-bold'
        }
      >
        {value}
      </dd>
      <dt className="text-[length:var(--text-caption)] text-text-muted">{label}</dt>
    </div>
  );
}
