import { argon2id } from './argon2id';

export type KdfParams = {
  algo?: string;
  memory_kib?: number;
  iterations?: number;
  parallelism?: number;
};

export const KEY_LENGTH = 32;
export const NONCE_LENGTH = 12;
export const TAG_LENGTH = 16;

const UMK_AAD_PREFIX = 'story.umk.v1|';
const DEK_AAD_PREFIX = 'story.dek.v1|';
const ITEM_INFO_PREFIX = 'story.vault.item.v1|';
const LABEL_INFO = 'story.vault.label.v1';

const encoder = new TextEncoder();
const decoder = new TextDecoder();

export function umkAad(userId: string) {
  return `${UMK_AAD_PREFIX}${userId}`;
}

export function itemBinding(saltItem: Uint8Array) {
  return toBase64(saltItem);
}

export function dekAad(saltItem: Uint8Array) {
  return `${DEK_AAD_PREFIX}${itemBinding(saltItem)}`;
}

export function fromBase64(value: string): Uint8Array {
  const binary = atob(value);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) out[i] = binary.charCodeAt(i);
  return out;
}

export function toBase64(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.length; i += 1) binary += String.fromCharCode(bytes[i]);
  return btoa(binary);
}

export function toHex(bytes: Uint8Array): string {
  let out = '';
  for (let i = 0; i < bytes.length; i += 1) {
    out += bytes[i].toString(16).padStart(2, '0');
  }
  return out;
}

export function deriveKek(
  secret: Uint8Array,
  salt: Uint8Array,
  kdf: KdfParams = {},
): Uint8Array {
  return argon2id({
    password: secret,
    salt,
    memoryKib: kdf.memory_kib ?? 65536,
    iterations: kdf.iterations ?? 3,
    parallelism: kdf.parallelism ?? 4,
    hashLength: KEY_LENGTH,
  });
}

async function hkdf(
  ikm: Uint8Array,
  salt: Uint8Array,
  info: Uint8Array,
): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey('raw', ikm as BufferSource, 'HKDF', false, [
    'deriveBits',
  ]);
  const bits = await crypto.subtle.deriveBits(
    { name: 'HKDF', hash: 'SHA-256', salt: salt as BufferSource, info: info as BufferSource },
    key,
    KEY_LENGTH * 8,
  );
  return new Uint8Array(bits);
}

export async function deriveItemKey({
  umk,
  passcodeKey,
  saltItem,
}: {
  umk: Uint8Array;
  passcodeKey: Uint8Array;
  saltItem: Uint8Array;
}): Promise<Uint8Array> {
  const ikm = new Uint8Array(umk.length + passcodeKey.length);
  ikm.set(umk, 0);
  ikm.set(passcodeKey, umk.length);

  return hkdf(ikm, saltItem, encoder.encode(`${ITEM_INFO_PREFIX}${itemBinding(saltItem)}`));
}

export async function unwrap({
  key,
  sealed,
  aad,
}: {
  key: Uint8Array;
  sealed: Uint8Array;
  aad: string;
}): Promise<Uint8Array> {
  if (sealed.length < NONCE_LENGTH + TAG_LENGTH) {
    throw new Error('Ciphertext is too short to be valid.');
  }

  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    key as BufferSource,
    'AES-GCM',
    false,
    ['decrypt'],
  );
  const plaintext = await crypto.subtle.decrypt(
    {
      name: 'AES-GCM',
      iv: sealed.subarray(0, NONCE_LENGTH) as BufferSource,
      additionalData: encoder.encode(aad) as BufferSource,
      tagLength: TAG_LENGTH * 8,
    },
    cryptoKey,
    sealed.subarray(NONCE_LENGTH) as BufferSource,
  );
  return new Uint8Array(plaintext);
}

export async function wrap({
  key,
  plaintext,
  aad,
}: {
  key: Uint8Array;
  plaintext: Uint8Array;
  aad: string;
}): Promise<Uint8Array> {
  const nonce = crypto.getRandomValues(new Uint8Array(NONCE_LENGTH));
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    key as BufferSource,
    'AES-GCM',
    false,
    ['encrypt'],
  );
  const sealed = await crypto.subtle.encrypt(
    {
      name: 'AES-GCM',
      iv: nonce as BufferSource,
      additionalData: encoder.encode(aad) as BufferSource,
      tagLength: TAG_LENGTH * 8,
    },
    cryptoKey,
    plaintext as BufferSource,
  );

  const out = new Uint8Array(NONCE_LENGTH + sealed.byteLength);
  out.set(nonce, 0);
  out.set(new Uint8Array(sealed), NONCE_LENGTH);
  return out;
}

export function normalizeLabel(label: string) {
  return label.trim();
}

export async function labelHash({
  umk,
  label,
}: {
  umk: Uint8Array;
  label: string;
}): Promise<string> {
  const labelKey = await hkdf(umk, new Uint8Array(0), encoder.encode(LABEL_INFO));

  const key = await crypto.subtle.importKey(
    'raw',
    labelKey as BufferSource,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const mac = await crypto.subtle.sign(
    'HMAC',
    key,
    encoder.encode(normalizeLabel(label)) as BufferSource,
  );
  return toHex(new Uint8Array(mac));
}

export async function unpack(
  bytes: Uint8Array,
  compression: string,
): Promise<Uint8Array> {
  if (compression !== 'gzip' || bytes.length === 0) return bytes;

  const stream = new Blob([bytes as BlobPart])
    .stream()
    .pipeThrough(new DecompressionStream('gzip'));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

export async function pack(
  bytes: Uint8Array,
  kind: string,
): Promise<{ bytes: Uint8Array; compression: string }> {
  if (kind !== 'pdf' || bytes.length === 0) return { bytes, compression: 'none' };

  const stream = new Blob([bytes as BlobPart])
    .stream()
    .pipeThrough(new CompressionStream('gzip'));
  const squeezed = new Uint8Array(await new Response(stream).arrayBuffer());

  return squeezed.length < bytes.length
    ? { bytes: squeezed, compression: 'gzip' }
    : { bytes, compression: 'none' };
}

export function decodeJson(bytes: Uint8Array): Record<string, unknown> {
  return JSON.parse(decoder.decode(bytes)) as Record<string, unknown>;
}
