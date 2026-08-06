const CEK_AAD_PREFIX = 'story.cek.v1|';
const MESSAGE_AAD_PREFIX = 'story.msg.v1|';
const SHARED_INFO = 'story.chat.shared.v1';
const NONCE_BYTES = 12;

const encoder = new TextEncoder();
const decoder = new TextDecoder();

export function pairKey(first: string, second: string) {
  return [first, second].sort().join(':');
}

export function toBase64(bytes: Uint8Array) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

export function fromBase64(value: string) {
  const binary = atob(value);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

export async function newIdentity() {
  return crypto.subtle.generateKey({ name: 'X25519' }, false, [
    'deriveBits',
  ]) as Promise<CryptoKeyPair>;
}

export async function exportPublicKey(pair: CryptoKeyPair) {
  const raw = await crypto.subtle.exportKey('raw', pair.publicKey);
  return toBase64(new Uint8Array(raw));
}

async function sharedKey(mine: CryptoKeyPair, theirPublicKey: string) {
  const peer = await crypto.subtle.importKey(
    'raw',
    fromBase64(theirPublicKey) as BufferSource,
    { name: 'X25519' },
    false,
    [],
  );
  const bits = await crypto.subtle.deriveBits(
    { name: 'X25519', public: peer },
    mine.privateKey,
    256,
  );

  const material = await crypto.subtle.importKey('raw', bits, 'HKDF', false, [
    'deriveKey',
  ]);
  return crypto.subtle.deriveKey(
    {
      name: 'HKDF',
      hash: 'SHA-256',
      salt: new Uint8Array(0) as BufferSource,
      info: encoder.encode(SHARED_INFO) as BufferSource,
    },
    material,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt'],
  );
}

async function seal(key: CryptoKey, plaintext: Uint8Array, aad: string) {
  const nonce = crypto.getRandomValues(new Uint8Array(NONCE_BYTES));
  const sealed = await crypto.subtle.encrypt(
    {
      name: 'AES-GCM',
      iv: nonce as BufferSource,
      additionalData: encoder.encode(aad) as BufferSource,
    },
    key,
    plaintext as BufferSource,
  );
  return toBase64(new Uint8Array([...nonce, ...new Uint8Array(sealed)]));
}

async function open(key: CryptoKey, sealed: string, aad: string) {
  const raw = fromBase64(sealed);
  const plaintext = await crypto.subtle.decrypt(
    {
      name: 'AES-GCM',
      iv: raw.slice(0, NONCE_BYTES) as BufferSource,
      additionalData: encoder.encode(aad) as BufferSource,
    },
    key,
    raw.slice(NONCE_BYTES) as BufferSource,
  );
  return new Uint8Array(plaintext);
}

export async function newConversationKey() {
  return crypto.getRandomValues(new Uint8Array(32));
}

export async function wrapForPeer(options: {
  cek: Uint8Array;
  mine: CryptoKeyPair;
  theirPublicKey: string;
  pair: string;
  recipientId: string;
}) {
  const key = await sharedKey(options.mine, options.theirPublicKey);
  return seal(
    key,
    options.cek,
    `${CEK_AAD_PREFIX}${options.pair}|${options.recipientId}`,
  );
}

export async function unwrapFromPeer(options: {
  wrapped: string;
  mine: CryptoKeyPair;
  theirPublicKey: string;
  pair: string;
  recipientId: string;
}) {
  const key = await sharedKey(options.mine, options.theirPublicKey);
  return open(
    key,
    options.wrapped,
    `${CEK_AAD_PREFIX}${options.pair}|${options.recipientId}`,
  );
}

async function messageKey(cek: Uint8Array) {
  return crypto.subtle.importKey('raw', cek as BufferSource, 'AES-GCM', false, [
    'encrypt',
    'decrypt',
  ]);
}

export async function encryptMessage(
  cek: Uint8Array,
  text: string,
  conversationId: string,
) {
  return seal(
    await messageKey(cek),
    encoder.encode(text),
    `${MESSAGE_AAD_PREFIX}${conversationId}`,
  );
}

export async function decryptMessage(
  cek: Uint8Array,
  ciphertext: string,
  conversationId: string,
) {
  const plaintext = await open(
    await messageKey(cek),
    ciphertext,
    `${MESSAGE_AAD_PREFIX}${conversationId}`,
  );
  return decoder.decode(plaintext);
}
