import type { Metadata } from 'next';
import { AsyncButton } from '@/components/AsyncButton';
import { cancelDeletion } from '@/lib/actions/account';
import { backendFetch } from '@/lib/server/session';
import type { TMe } from '@/lib/types';
import { LeavingForms } from './LeavingForms';

export const metadata: Metadata = { title: 'Leaving' };

export default async function LeavingPage() {
  const result = await backendFetch<{ user: TMe }>('/auth/me');
  const isLeaving = result.ok && result.value.user.status === 'pending_deletion';

  if (isLeaving) {
    return (
      <div className="mx-auto max-w-lg">
        <h1 className="text-[length:var(--text-title)] font-semibold">Leaving</h1>
        <div className="mt-6 rounded-[length:var(--radius-md)] border border-danger bg-surface p-6">
          <h2 className="text-[length:var(--text-heading)] font-bold text-danger">
            Your account is scheduled for deletion
          </h2>
          <p className="mt-3 leading-relaxed text-text-secondary">
            Nothing has been removed yet. Cancel and everything stays exactly as it is.
          </p>
          <div className="mt-5">
            <AsyncButton label="Keep my account" variant="primary" action={cancelDeletion} />
          </div>
        </div>
      </div>
    );
  }

  return <LeavingForms />;
}
