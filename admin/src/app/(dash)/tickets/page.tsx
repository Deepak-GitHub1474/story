import type { Metadata } from 'next';
import Link from 'next/link';
import { Badge } from '@/components/ui/Surface';
import { ChipLink } from '@/components/ui/Chip';
import { PageHeader } from '@/components/ui/PageHeader';
import { requireStaff } from '@/lib/server/guard';
import { backendFetch } from '@/lib/server/session';
import { relativeTime } from '@/lib/format';
import type { TTicket } from '@/lib/types';

export const metadata: Metadata = { title: 'Tickets' };

type Props = { searchParams: Promise<{ closed?: string }> };

const LABELS: Record<string, string> = {
  passcode_release: 'Passcode release',
  account_locked: 'Account locked',
  content_appeal: 'Content appeal',
  data_export: 'Data export',
  account_deletion: 'Account deletion',
  security_incident: 'Security incident',
};

export default async function TicketsPage({ searchParams }: Props) {
  const staff = await requireStaff();
  const { closed } = await searchParams;
  const includeClosed = closed === 'true';

  const result = await backendFetch<{ items: TTicket[] }>(
    `/admin/tickets${includeClosed ? '?include_closed=true' : ''}`,
  );
  const tickets = result.ok ? result.value.items : [];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Tickets"
        description="Oldest first, and only the kinds your role may handle. A ticket type is never re-routable downward, so an escrow release never appears here for anyone but a super_admin."
      />

      <div className="flex gap-2">
        <ChipLink href="/tickets" isActive={!includeClosed}>
          Open
        </ChipLink>
        <ChipLink href="/tickets?closed=true" isActive={includeClosed}>
          Everything
        </ChipLink>
      </div>

      {tickets.length === 0 ? (
        <p className="rounded-[length:var(--radius-lg)] border border-border bg-surface px-6 py-16 text-center text-[length:var(--text-label)] text-text-muted">
          {includeClosed ? 'No tickets at all yet.' : 'Nothing waiting.'}
        </p>
      ) : (
        <ul className="space-y-3">
          {tickets.map((ticket) => (
            <li
              key={ticket.ticket_id}
              className="rounded-[length:var(--radius-lg)] border border-border bg-surface p-4 transition-colors duration-[var(--motion-fast)] hover:border-border-strong sm:p-5"
            >
              <div className="flex flex-wrap items-center gap-3">
                <h2 className="text-[length:var(--text-heading)] font-semibold tracking-[var(--tracking-title)]">
                  {LABELS[ticket.type] ?? ticket.type}
                </h2>
                <Badge
                  tone={
                    ticket.state === 'reveal_ready'
                      ? 'success'
                      : ticket.state === 'needs_more_info'
                        ? 'warning'
                        : 'neutral'
                  }
                >
                  {ticket.state.replace(/_/g, ' ')}
                </Badge>
                <span className="text-[length:var(--text-caption)] text-text-muted">
                  {relativeTime(ticket.created_at)}
                </span>
                <code className="numeric ml-auto text-[length:var(--text-micro)] text-text-muted">
                  {ticket.ticket_id}
                </code>
              </div>

              <p className="mt-3 max-w-[75ch] text-[length:var(--text-label)] leading-relaxed text-text-secondary">
                {ticket.reason}
              </p>

              <div className="mt-4 flex flex-wrap items-center gap-x-5 gap-y-2 border-t border-border pt-4">
                {ticket.opened_by.username ? (
                  staff.role === 'moderator' ? (
                    <span className="text-[length:var(--text-label)] text-text-muted">
                      Opened by @{ticket.opened_by.username}
                    </span>
                  ) : (
                    <Link
                      href={`/users/${ticket.opened_by.username}`}
                      className="text-[length:var(--text-label)] text-accent underline-offset-4 hover:underline"
                    >
                      Opened by @{ticket.opened_by.username}
                    </Link>
                  )
                ) : (
                  <span className="text-[length:var(--text-label)] text-text-muted">
                    Opened by a deleted account
                  </span>
                )}

                {ticket.type === 'passcode_release' &&
                staff.role === 'super_admin' &&
                ticket.opened_by.username ? (
                  <Link
                    href={`/vault?username=${ticket.opened_by.username}&ticket=${ticket.ticket_id}`}
                    className="text-[length:var(--text-label)] text-danger underline-offset-4 hover:underline"
                  >
                    Open the escrow release
                  </Link>
                ) : null}
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
