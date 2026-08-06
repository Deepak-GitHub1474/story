const DB_NAME = 'story.chat';
const STORE = 'identity';

export type StoredIdentity = { seed: string; publicKey: string };

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = () => request.result.createObjectStore(STORE);
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

function run<T>(
  mode: IDBTransactionMode,
  work: (store: IDBObjectStore) => IDBRequest<T>,
): Promise<T> {
  return openDb().then(
    (db) =>
      new Promise<T>((resolve, reject) => {
        const request = work(db.transaction(STORE, mode).objectStore(STORE));
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      }),
  );
}

export async function readIdentity(userId: string) {
  try {
    return (await run('readonly', (store) => store.get(userId))) as
      | StoredIdentity
      | undefined;
  } catch {
    return undefined;
  }
}

export async function writeIdentity(userId: string, identity: StoredIdentity) {
  await run('readwrite', (store) => store.put(identity, userId));
}
