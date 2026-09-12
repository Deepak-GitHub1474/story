import type { Metadata } from 'next';
import { ReportCard } from '@/components/ReportCard';
import { PageHeader } from '@/components/ui/PageHeader';
import { Stat } from '@/components/ui/Surface';
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
      <PageHeader
        title="Report queue"
        description="Oldest first. Actioning removes the content and writes the reason to the audit log; dismissing leaves it where it is."
      />

      {stats ? (
        <dl className="grid grid-cols-2 gap-2 sm:grid-cols-4 lg:grid-cols-7">
          <Stat
            label="Open reports"
            value={stats.open_reports}
            tone={stats.open_reports > 0 ? 'danger' : 'neutral'}
          />
          <Stat
            label="Open tickets"
            value={stats.open_tickets ?? 0}
            tone={(stats.open_tickets ?? 0) > 0 ? 'warning' : 'neutral'}
          />
          <Stat label="Accounts" value={stats.users} />
          <Stat label="Blocked" value={stats.blocked_users} />
          <Stat label="Stories" value={stats.stories} />
          <Stat label="Comments" value={stats.comments} />
          <Stat label="Rooms" value={stats.communities} />
        </dl>
      ) : null}

      {reports.length === 0 ? (
        <p className="rounded-[length:var(--radius-lg)] border border-border bg-surface px-6 py-16 text-center text-[length:var(--text-label)] text-text-muted">
          Nothing waiting. The queue is empty.
        </p>
      ) : (
        <ul className="space-y-2">
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
