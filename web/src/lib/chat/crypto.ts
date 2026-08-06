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

const PKCS8_X25519_PREFIX = new Uint8Array([
  0x30, 0x2e, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x6e, 0x04,
  0x22, 0x04, 0x20,
]);

export type Identity = { privateKey: CryptoKey; publicKey: string };

export async function newIdentity(): Promise<Identity & { seed: Uint8Array }> {
  const pair = (await crypto.subtle.generateKey({ name: 'X25519' }, true, [
    'deriveBits',
  ])) as CryptoKeyPair;

  const pkcs8 = new Uint8Array(
    await crypto.subtle.exportKey('pkcs8', pair.privateKey),
  );
  const raw = await crypto.subtle.exportKey('raw', pair.publicKey);

  return {
    privateKey: pair.privateKey,
    publicKey: toBase64(new Uint8Array(raw)),
    seed: pkcs8.slice(-32),
  };
}

export async function importIdentity(
  seed: Uint8Array,
  publicKey: string,
): Promise<Identity> {
  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    new Uint8Array([...PKCS8_X25519_PREFIX, ...seed]) as BufferSource,
    { name: 'X25519' },
    true,
    ['deriveBits'],
  );
  return { privateKey, publicKey };
}

async function sharedKey(mine: Identity, theirPublicKey: string) {
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
  mine: Identity;
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
  mine: Identity;
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

const IDENTITY_AAD_PREFIX = 'story.chat.identity.v1|';

export function randomSalt() {
  return toBase64(crypto.getRandomValues(new Uint8Array(16)));
}

async function identityKey(password: string, salt: string) {
  const material = await crypto.subtle.importKey(
    'raw',
    encoder.encode(password) as BufferSource,
    'PBKDF2',
    false,
    ['deriveKey'],
  );
  return crypto.subtle.deriveKey(
    {
      name: 'PBKDF2',
      hash: 'SHA-256',
      salt: fromBase64(salt) as BufferSource,
      iterations: 600000,
    },
    material,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt'],
  );
}

export async function wrapIdentityRaw(options: {
  privateKeyRaw: Uint8Array;
  password: string;
  salt: string;
  userId: string;
}) {
  const key = await identityKey(options.password, options.salt);
  return seal(
    key,
    options.privateKeyRaw,
    `${IDENTITY_AAD_PREFIX}${options.userId}`,
  );
}

export async function unwrapIdentityRaw(options: {
  wrapped: string;
  password: string;
  salt: string;
  userId: string;
}) {
  const key = await identityKey(options.password, options.salt);
  return open(key, options.wrapped, `${IDENTITY_AAD_PREFIX}${options.userId}`);
}
