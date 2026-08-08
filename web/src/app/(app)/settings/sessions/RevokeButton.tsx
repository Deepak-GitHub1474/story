'use client';

import { useTransition } from 'react';
import { revokeSession } from '@/lib/actions/account';

export function RevokeButton({ familyId }: { familyId: string }) {
  const [isPending, startTransition] = useTransition();

  return (
    <button
      type="button"
      disabled={isPending}
      onClick={() => startTransition(async () => void (await revokeSession(familyId)))}
      className="text-[length:var(--text-label)] font-medium text-danger hover:underline disabled:opacity-50"
    >
      Revoke
    </button>
  );
}
