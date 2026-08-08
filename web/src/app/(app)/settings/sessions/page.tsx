import type { Metadata } from 'next';
import { RevokeButton } from './RevokeButton';
import { backendFetch } from '@/lib/server/session';

export const metadata: Metadata = { title: 'Active sessions' };

type TSession = {
  family_id: string;
  is_current: boolean;
  label: string;
  platform: string;
};

export default async function SessionsPage() {
  const result = await backendFetch<{ items: TSession[] }>('/auth/sessions');
  const sessions = result.ok ? result.value.items : [];

  return (
    <div className="mx-auto max-w-lg">
      <h1 className="text-[length:var(--text-title)] font-medium">Active sessions</h1>
      <p className="mt-2 leading-relaxed text-text-secondary">
        Every device signed in to this account. Revoking one signs it out within a
        minute.
      </p>

      <ul className="mt-8 divide-y divide-border border-y border-border">
        {sessions.map((session) => (
          <li key={session.family_id} className="flex items-center gap-4 py-4">
            <span className="min-w-0 flex-1">
              <span className="block font-medium">{session.label}</span>
              <span
                className={
                  session.is_current
                    ? 'block text-[length:var(--text-caption)] text-success'
                    : 'block text-[length:var(--text-caption)] text-text-muted'
                }
              >
                {session.is_current ? 'This device' : session.platform}
              </span>
            </span>
            {!session.is_current ? <RevokeButton familyId={session.family_id} /> : null}
          </li>
        ))}
      </ul>
    </div>
  );
}
