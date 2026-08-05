'use client';

import { useTransition } from 'react';
import { reportTarget } from '@/lib/actions/stories';

export const REPORT_REASONS = [
  ['harassment', 'Harassment', 'Targeting or attacking someone.'],
  ['spam', 'Spam', 'Promotion, repetition, or link farming.'],
  ['self_harm', 'Someone at risk', 'This person may be in danger.'],
  ['illegal', 'Illegal', 'Illegal goods, services, or content.'],
  ['impersonation', 'Impersonation', 'Pretending to be a real person.'],
  ['wrong_community', 'Wrong room', 'Does not belong in this community.'],
  ['other', 'Something else', 'Tell us in your own words.'],
] as const;

export function ReportMenu({
  kind,
  targetId,
  onDone,
}: {
  kind: 'story' | 'comment' | 'user';
  targetId: string;
  onDone: (notice: string) => void;
}) {
  const [, startTransition] = useTransition();

  return (
    <div role="group" aria-label="Report reason">
      <p className="border-b border-border px-4 py-3 text-[length:var(--text-caption)] leading-relaxed text-text-muted">
        A person reads every report. The author is never told who sent it.
      </p>
      {REPORT_REASONS.map(([value, label, description]) => (
        <button
          key={value}
          type="button"
          onClick={() =>
            startTransition(async () => {
              await reportTarget(kind, targetId, value);
              onDone('Reported. Thank you.');
            })
          }
          className="block w-full px-4 py-3 text-left transition-colors hover:bg-surface-raised"
        >
          <span className="block text-[length:var(--text-label)]">{label}</span>
          <span className="block text-[length:var(--text-caption)] text-text-muted">
            {description}
          </span>
        </button>
      ))}
    </div>
  );
}
