'use client';

import { useEffect, useState } from 'react';
import {
  fromBase64,
  importIdentity,
  newIdentity,
  randomSalt,
  toBase64,
  unwrapIdentityRaw,
  wrapIdentityRaw,
  type Identity,
} from './crypto';
import { readIdentity, writeIdentity } from './keystore';
import { publishChatKey, readChatBackup, storeChatBackup } from '@/lib/actions/chat';

export type IdentityState =
  | { status: 'loading' }
  | { status: 'unsupported' }
  | { status: 'locked' }
  | { status: 'ready'; identity: Identity };

export function useChatIdentity(userId: string): IdentityState {
  const [state, setState] = useState<IdentityState>({ status: 'loading' });

  useEffect(() => {
    if (!userId) return;
    let cancelled = false;

    (async () => {
      try {
        const stored = await readIdentity(userId);
        if (stored) {
          const identity = await importIdentity(
            fromBase64(stored.seed),
            stored.publicKey,
          );
          await publishChatKey(stored.publicKey);
          if (!cancelled) setState({ status: 'ready', identity });
          return;
        }

        const backup = await readChatBackup();
        if (backup) {
          if (!cancelled) setState({ status: 'locked' });
          return;
        }

        const fresh = await newIdentity();
        await writeIdentity(userId, {
          seed: toBase64(fresh.seed),
          publicKey: fresh.publicKey,
        });
        await publishChatKey(fresh.publicKey);
        if (!cancelled) {
          setState({
            status: 'ready',
            identity: { privateKey: fresh.privateKey, publicKey: fresh.publicKey },
          });
        }
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

export async function bootstrapChat(userId: string, password: string) {
  try {
    const backup = await readChatBackup();

    if (backup) {
      const seed = await unwrapIdentityRaw({
        wrapped: backup.wrapped_private_key,
        password,
        salt: backup.salt,
        userId,
      });
      await writeIdentity(userId, {
        seed: toBase64(seed),
        publicKey: backup.public_key,
      });
      await publishChatKey(backup.public_key);
      return;
    }

    const stored = await readIdentity(userId);
    if (stored) {
      await backUpIdentity(userId, password, fromBase64(stored.seed), stored.publicKey);
      await publishChatKey(stored.publicKey);
      return;
    }

    const fresh = await newIdentity();
    await writeIdentity(userId, {
      seed: toBase64(fresh.seed),
      publicKey: fresh.publicKey,
    });
    await backUpIdentity(userId, password, fresh.seed, fresh.publicKey);
    await publishChatKey(fresh.publicKey);
  } catch {
    return;
  }
}

export async function unlockWithPassword(userId: string, password: string) {
  const backup = await readChatBackup();
  if (!backup) return false;

  const seed = await unwrapIdentityRaw({
    wrapped: backup.wrapped_private_key,
    password,
    salt: backup.salt,
    userId,
  });

  await writeIdentity(userId, {
    seed: toBase64(seed),
    publicKey: backup.public_key,
  });
  await publishChatKey(backup.public_key);
  return true;
}

export async function backUpIdentity(
  userId: string,
  password: string,
  seed: Uint8Array,
  publicKey: string,
) {
  const salt = randomSalt();
  await storeChatBackup({
    salt,
    wrapped_private_key: await wrapIdentityRaw({
      privateKeyRaw: seed,
      password,
      salt,
      userId,
    }),
    public_key: publicKey,
    kdf: {
      algo: 'pbkdf2-sha256',
      memory_kib: 0,
      iterations: 600000,
      parallelism: 1,
    },
  });
}
