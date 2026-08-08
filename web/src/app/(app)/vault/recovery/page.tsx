import type { Metadata } from 'next';
import { Card, Section, Row } from '@/components/ui/Surface';
import { backendFetch } from '@/lib/server/session';
import { RecoveryForm } from './RecoveryForm';

export const metadata: Metadata = { title: 'Vault recovery' };

type TTicket = {
  ticket_id: string;
  type: string;
  state: string;
  reason: string;
  created_at: string;
};

type TEvent = {
  action: string;
  outcome: string;
  occurred_at: string;
  by_role: string | null;
};

const STATE_LABELS: Record<string, string> = {
  submitted: 'Waiting for a person to pick it up',
  under_review: 'A person is reviewing it',
  needs_more_info: 'They need more from you',
  reveal_ready: 'Approved. Your passcode is ready to collect.',
  closed: 'Closed',
  rejected: 'Rejected',
};

const EVENT_LABELS: Record<string, string> = {
  'passcode_release.approved': 'A super admin released your passcode',
  'vault.passcodes_listed': 'A super admin saw your passcode names',
  'account.blocked': 'Your account was blocked',
  'account.unblocked': 'Your account was unblocked',
};

const OPEN_STATES = ['submitted', 'under_review', 'needs_more_info', 'reveal_ready'];

export default async function VaultRecoveryPage() {
  const [ticketsResult, activityResult] = await Promise.all([
    backendFetch<{ items: TTicket[] }>('/tickets'),
    backendFetch<{ items: TEvent[] }>('/security-activity'),
  ]);

  const tickets = ticketsResult.ok ? ticketsResult.value.items : [];
  const activity = activityResult.ok ? activityResult.value.items : [];
  const hasOpen = tickets.some((ticket) => OPEN_STATES.includes(ticket.state));

  return (
    <div className="mx-auto flex max-w-lg flex-col gap-8">
      <div>
        <h1 className="text-[length:var(--text-title)] font-medium">Recovery</h1>
        <Card className="mt-6">
          <h2 className="font-medium">What we can and cannot do</h2>
          <p className="mt-2 leading-relaxed text-text-secondary">
            Forgot your account password? Nobody can recover it, and nothing in your
            vault survives without it.
          </p>
          <p className="mt-3 leading-relaxed text-text-secondary">
            Forgot only your vault passcode? A super admin can release the copy you
            sealed when you created it. It goes to you, never to them, and you still
            need your password to open anything.
          </p>
        </Card>
      </div>

      <Section title="Your requests">
        {tickets.length === 0 ? (
          <p className="px-4 py-5 text-text-muted">You have not asked for anything.</p>
        ) : (
          tickets.map((ticket) => (
            <div key={ticket.ticket_id} className="px-4 py-4">
              <p className="font-medium">
                {STATE_LABELS[ticket.state] ?? ticket.state}
              </p>
              <p className="mt-1 text-[length:var(--text-caption)] text-text-muted">
                {ticket.reason}
              </p>
            </div>
          ))
        )}
      </Section>

      {hasOpen ? null : <RecoveryForm />}

      <Section title="Who touched your account">
        {activity.length === 0 ? (
          <p className="px-4 py-5 text-text-muted">
            No staff has touched your account.
          </p>
        ) : (
          activity.map((event, index) => (
            <Row
              key={`${event.action}-${index}`}
              label={EVENT_LABELS[event.action] ?? event.action}
              value={event.occurred_at.split('T')[0]}
            />
          ))
        )}
      </Section>
    </div>
  );
}
