import type { Metadata } from 'next';
import { requireUser } from '@/lib/server/guard';
import { backendFetch } from '@/lib/server/session';
import { VaultClient } from './VaultClient';

export const metadata: Metadata = { title: 'Vault' };

type TOverview = {
  item_count: number;
  used_bytes: number;
  limit_bytes: number;
  passcodes: { passcode_id: string; label: string; scope: string }[];
};

export default async function VaultPage() {
  const me = await requireUser();
  const result = await backendFetch<TOverview>('/vault/overview');
  const overview = result.ok ? result.value : null;

  return (
    <VaultClient
      userId={me.user_id}
      vaults={(overview?.passcodes ?? [])
        .filter((passcode) => passcode.scope === 'vault')
        .map((passcode) => ({ id: passcode.passcode_id, label: passcode.label }))}
      hasPasscode={Boolean(overview?.passcodes.length)}
      itemCount={overview?.item_count ?? 0}
      usedBytes={overview?.used_bytes ?? 0}
      limitBytes={overview?.limit_bytes ?? 0}
    />
  );
}
