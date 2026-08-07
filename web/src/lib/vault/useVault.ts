'use client';

import { useCallback, useRef, useState } from 'react';
import {
  dekAad,
  decodeJson,
  deriveItemKey,
  fromBase64,
  labelHash,
  umkAad,
  unpack,
  unwrap,
  type KdfParams,
} from './crypto';
import {
  findSealed,
  loadItem,
  loadItems,
  loadKeys,
  loadPasscodes,
} from '@/lib/actions/vault';
import type { TVaultItem } from '@/lib/types';

export type OpenItem = TVaultItem & {
  filename: string;
  mime: string;
  compression: string;
};

type Session = { umk: Uint8Array; passcodeKey: Uint8Array; passcodeId: string };

function deriveInWorker(payload: {
  password: string;
  passcode: string;
  saltPw: Uint8Array;
  saltPc: Uint8Array;
  kdf: KdfParams;
  passcodeKdf: KdfParams;
}): Promise<{ kek: Uint8Array; passcodeKey: Uint8Array }> {
  return new Promise((resolve, reject) => {
    const worker = new Worker(new URL('./unlock.worker.ts', import.meta.url));

    worker.onmessage = (event) => {
      worker.terminate();
      if (event.data.error) {
        reject(new Error(event.data.error));
        return;
      }
      resolve({
        kek: new Uint8Array(event.data.kek),
        passcodeKey: new Uint8Array(event.data.passcodeKey),
      });
    };
    worker.onerror = () => {
      worker.terminate();
      reject(new Error('The vault could not start in this browser.'));
    };

    worker.postMessage(payload);
  });
}

export function useVault(userId: string) {
  const session = useRef<Session | null>(null);
  const [isUnlocked, setIsUnlocked] = useState(false);
  const [isWorking, setIsWorking] = useState(false);
  const [items, setItems] = useState<OpenItem[]>([]);
  const [error, setError] = useState<string | null>(null);

  const describe = useCallback(async (item: TVaultItem, umk: Uint8Array, passcodeKey: Uint8Array) => {
    const detail = item.wrapped_dek ? item : await loadItem(item.item_id);
    if (!detail?.wrapped_dek || !detail.salt_item) return null;

    const saltItem = fromBase64(detail.salt_item);
    const itemKey = await deriveItemKey({ umk, passcodeKey, saltItem });
    const dek = await unwrap({
      key: itemKey,
      sealed: fromBase64(detail.wrapped_dek),
      aad: dekAad(saltItem),
    });
    const metadata = decodeJson(
      await unwrap({
        key: dek,
        sealed: fromBase64(detail.encrypted_metadata),
        aad: dekAad(saltItem),
      }),
    );

    return {
      ...detail,
      filename: String(metadata.filename ?? 'Untitled'),
      mime: String(metadata.mime ?? 'application/octet-stream'),
      compression: String(metadata.compression ?? 'none'),
    } satisfies OpenItem;
  }, []);

  const unlock = useCallback(
    async (password: string, passcode: string, passcodeId: string) => {
      setIsWorking(true);
      setError(null);

      try {
        const [keys, passcodes] = await Promise.all([loadKeys(), loadPasscodes()]);
        const record = passcodes.find((row) => row.passcode_id === passcodeId);

        if (!keys || !record) {
          setError('Set your vault up on the app first.');
          return false;
        }

        const { kek, passcodeKey } = await deriveInWorker({
          password,
          passcode,
          saltPw: fromBase64(keys.salt_pw),
          saltPc: fromBase64(record.salt_pc),
          kdf: keys.kdf as KdfParams,
          passcodeKdf: (Object.keys(record.kdf).length ? record.kdf : keys.kdf) as KdfParams,
        });

        let umk: Uint8Array;
        try {
          umk = await unwrap({
            key: kek,
            sealed: fromBase64(keys.wrapped_umk),
            aad: umkAad(userId),
          });
        } catch {
          setError('That password did not unlock your vault.');
          return false;
        }

        const listed = await loadItems(passcodeId);
        const described = await Promise.all(
          listed.map((item) => describe(item, umk, passcodeKey).catch(() => null)),
        );

        if (listed.length > 0 && described.every((item) => item === null)) {
          setError('That passcode did not open this vault.');
          return false;
        }

        session.current = { umk, passcodeKey, passcodeId };
        setItems(described.filter((item): item is OpenItem => item !== null));
        setIsUnlocked(true);
        return true;
      } finally {
        setIsWorking(false);
      }
    },
    [describe, userId],
  );

  const lock = useCallback(() => {
    session.current?.umk.fill(0);
    session.current?.passcodeKey.fill(0);
    session.current = null;
    setItems([]);
    setIsUnlocked(false);
    setError(null);
  }, []);

  const open = useCallback(async (item: OpenItem) => {
    const current = session.current;
    if (!current) return null;

    if (!item.salt_item || !item.wrapped_dek) return null;

    const response = await fetch(`/api/vault/${item.item_id}`);
    if (!response.ok) return null;
    const ciphertext = new Uint8Array(await response.arrayBuffer());

    const saltItem = fromBase64(item.salt_item);
    const itemKey = await deriveItemKey({
      umk: current.umk,
      passcodeKey: current.passcodeKey,
      saltItem,
    });
    const dek = await unwrap({
      key: itemKey,
      sealed: fromBase64(item.wrapped_dek),
      aad: dekAad(saltItem),
    });
    const packed = await unwrap({ key: dek, sealed: ciphertext, aad: dekAad(saltItem) });

    const bytes = await unpack(packed, item.compression);
    return URL.createObjectURL(new Blob([bytes as BlobPart], { type: item.mime }));
  }, []);

  const findByLabel = useCallback(
    async (label: string) => {
      const current = session.current;
      if (!current || !label.trim()) return null;

      const hash = await labelHash({ umk: current.umk, label });
      const found = await findSealed(hash);
      if (!found) return null;

      return describe(found, current.umk, current.passcodeKey);
    },
    [describe],
  );

  return { isUnlocked, isWorking, items, error, unlock, lock, open, findByLabel };
}
