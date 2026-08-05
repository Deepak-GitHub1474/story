'use client';

import Link from 'next/link';
import { useTransition } from 'react';
import { Button } from '@/components/ui/Button';
import { Badge } from '@/components/ui/Surface';
import { relativeTime } from '@/lib/format';
import { resolveReport } from '@/lib/actions';
import type { TReport } from '@/lib/types';

const REASON_TONE: Record<string, 'danger' | 'accent' | 'neutral'> = {
  self_harm: 'danger',
  illegal: 'danger',
  harassment: 'danger',
  impersonation: 'accent',
  spam: 'neutral',
  wrong_community: 'neutral',
  other: 'neutral',
};

export function ReportCard({ report }: { report: TReport }) {
  const [isPending, startTransition] = useTransition();

  return (
    <article className="rounded-[length:var(--radius-md)] border border-border bg-surface p-5">
      <div className="flex flex-wrap items-center gap-3">
        <Badge tone={REASON_TONE[report.reason] ?? 'neutral'}>
          {report.reason.replace(/_/g, ' ')}
        </Badge>
        <span className="text-[length:var(--text-caption)] text-text-muted">
          {report.target.kind} · {relativeTime(report.created_at)}
        </span>
        {report.target.author ? (
          <Link
            href={`/users/${report.target.author}`}
            className="text-[length:var(--text-caption)] text-accent hover:underline"
          >
            {report.target.author}
          </Link>
        ) : null}
      </div>

      {report.target.title ? (
        <h2 className="mt-3 font-semibold">{report.target.title}</h2>
      ) : null}

      <p className="mt-2 leading-relaxed text-text-secondary">{report.target.excerpt}</p>

      {report.note ? (
        <p className="mt-3 rounded-[length:var(--radius-sm)] bg-surface-raised px-3 py-2 text-[length:var(--text-caption)] text-text-secondary">
          Reporter note: {report.note}
        </p>
      ) : null}

      <div className="mt-5 flex flex-wrap gap-2">
        <Button
          size="sm"
          variant="danger"
          isFullWidth={false}
          isLoading={isPending}
          onClick={() =>
            startTransition(async () => {
              await resolveReport(report.report_id, 'actioned');
            })
          }
        >
          Remove content
        </Button>
        <Button
          size="sm"
          variant="secondary"
          isFullWidth={false}
          onClick={() =>
            startTransition(async () => {
              await resolveReport(report.report_id, 'dismissed');
            })
          }
        >
          Dismiss
        </Button>
      </div>
    </article>
  );
}
