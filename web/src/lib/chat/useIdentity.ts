'use client';

import { useEffect, useState } from 'react';
import { exportPublicKey, newIdentity } from './crypto';
import { readIdentity, writeIdentity } from './keystore';
import { publishChatKey } from '@/lib/actions/chat';

export type IdentityState =
  | { status: 'loading' }
  | { status: 'unsupported' }
  | { status: 'ready'; pair: CryptoKeyPair; publicKey: string };

export function useChatIdentity(userId: string): IdentityState {
  const [state, setState] = useState<IdentityState>({ status: 'loading' });

  useEffect(() => {
    let cancelled = false;

    (async () => {
      try {
        const existing = await readIdentity(userId);
        const pair = existing ?? (await newIdentity());
        if (!existing) await writeIdentity(userId, pair);

        const publicKey = await exportPublicKey(pair);
        await publishChatKey(publicKey);
        if (!cancelled) setState({ status: 'ready', pair, publicKey });
      } catch {
        if (!cancelled) setState({ status: 'unsupported' });
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [userId]);

  return state;
}
