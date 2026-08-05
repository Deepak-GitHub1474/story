import type { Metadata } from 'next';
import { requireStaff } from '@/lib/server/guard';
import { backendFetch } from '@/lib/server/session';
import { TotpSetup } from './TotpSetup';

export const metadata: Metadata = { title: 'Security' };

type TStatus = {
  enabled: boolean;
  started: boolean;
  enabled_at: string | null;
  backups_left: number;
};

export default async function SecurityPage() {
  await requireStaff();
  const result = await backendFetch<TStatus>('/auth/totp');
  const status = result.ok ? result.value : null;

  return (
    <div className="max-w-xl">
      <h1 className="text-[length:var(--text-title)] font-semibold">Security</h1>

      <p className="mt-3 leading-relaxed text-text-secondary">
        Releasing an escrowed passcode needs a code from an authenticator app on
        your phone. Without one you can still see passcode names, but you cannot
        approve a release.
      </p>

      <div className="mt-8">
        <TotpSetup
          isEnabled={Boolean(status?.enabled)}
          backupsLeft={status?.backups_left ?? 0}
        />
      </div>
    </div>
  );
}
