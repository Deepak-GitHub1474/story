const IV = new Uint32Array([
  0xf3bcc908, 0x6a09e667, 0x84caa73b, 0xbb67ae85, 0xfe94f82b, 0x3c6ef372, 0x5f1d36f1,
  0xa54ff53a, 0xade682d1, 0x510e527f, 0x2b3e6c1f, 0x9b05688c, 0xfb41bd6b, 0x1f83d9ab,
  0x137e2179, 0x5be0cd19,
]);

const SIGMA = new Uint8Array([
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 14, 10, 4, 8, 9, 15, 13, 6, 1,
  12, 0, 2, 11, 7, 5, 3, 11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4, 7, 9, 3,
  1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8, 9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12,
  6, 8, 3, 13, 2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9, 12, 5, 1, 15, 14,
  13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11, 13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2,
  10, 6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5, 10, 2, 8, 4, 7, 6, 1, 5, 15,
  11, 9, 14, 3, 12, 13, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 14, 10,
  4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3,
]);

const v = new Uint32Array(32);
const m = new Uint32Array(32);

function add64AA(a: Uint32Array, i: number, j: number) {
  const low = a[i] + a[j];
  a[i] = low >>> 0;
  a[i + 1] = (a[i + 1] + a[j + 1] + (low >= 0x100000000 ? 1 : 0)) >>> 0;
}

function add64AC(a: Uint32Array, i: number, low: number, high: number) {
  const sum = a[i] + (low >>> 0);
  a[i] = sum >>> 0;
  a[i + 1] = (a[i + 1] + high + (sum >= 0x100000000 ? 1 : 0)) >>> 0;
}

function mix(i: number, j: number, a: number, b: number, c: number, d: number) {
  add64AA(v, a, b);
  add64AC(v, a, m[i], m[i + 1]);

  let xor0 = v[d] ^ v[a];
  let xor1 = v[d + 1] ^ v[a + 1];
  v[d] = xor1;
  v[d + 1] = xor0;

  add64AA(v, c, d);

  xor0 = v[b] ^ v[c];
  xor1 = v[b + 1] ^ v[c + 1];
  v[b] = (xor0 >>> 24) ^ (xor1 << 8);
  v[b + 1] = (xor1 >>> 24) ^ (xor0 << 8);

  add64AA(v, a, b);
  add64AC(v, a, m[j], m[j + 1]);

  xor0 = v[d] ^ v[a];
  xor1 = v[d + 1] ^ v[a + 1];
  v[d] = (xor0 >>> 16) ^ (xor1 << 16);
  v[d + 1] = (xor1 >>> 16) ^ (xor0 << 16);

  add64AA(v, c, d);

  xor0 = v[b] ^ v[c];
  xor1 = v[b + 1] ^ v[c + 1];
  v[b] = (xor1 >>> 31) ^ (xor0 << 1);
  v[b + 1] = (xor0 >>> 31) ^ (xor1 << 1);
}

type State = {
  h: Uint32Array;
  t: number;
  buffer: Uint8Array;
  view: DataView;
  fill: number;
  outlen: number;
};

function compress(state: State, isLast: boolean) {
  for (let i = 0; i < 16; i += 1) v[i] = state.h[i];
  for (let i = 0; i < 16; i += 1) v[i + 16] = IV[i];

  v[24] = (v[24] ^ state.t) >>> 0;
  v[25] = (v[25] ^ Math.floor(state.t / 0x100000000)) >>> 0;
  if (isLast) {
    v[28] = ~v[28] >>> 0;
    v[29] = ~v[29] >>> 0;
  }

  for (let i = 0; i < 32; i += 1) m[i] = state.view.getUint32(i * 4, true);

  for (let round = 0; round < 12; round += 1) {
    const s = round * 16;
    mix(SIGMA[s] * 2, SIGMA[s + 1] * 2, 0, 8, 16, 24);
    mix(SIGMA[s + 2] * 2, SIGMA[s + 3] * 2, 2, 10, 18, 26);
    mix(SIGMA[s + 4] * 2, SIGMA[s + 5] * 2, 4, 12, 20, 28);
    mix(SIGMA[s + 6] * 2, SIGMA[s + 7] * 2, 6, 14, 22, 30);
    mix(SIGMA[s + 8] * 2, SIGMA[s + 9] * 2, 0, 10, 20, 30);
    mix(SIGMA[s + 10] * 2, SIGMA[s + 11] * 2, 2, 12, 22, 24);
    mix(SIGMA[s + 12] * 2, SIGMA[s + 13] * 2, 4, 14, 16, 26);
    mix(SIGMA[s + 14] * 2, SIGMA[s + 15] * 2, 6, 8, 18, 28);
  }

  for (let i = 0; i < 16; i += 1) {
    state.h[i] = (state.h[i] ^ v[i] ^ v[i + 16]) >>> 0;
  }
}

function create(outlen: number, key: Uint8Array | null): State {
  const buffer = new Uint8Array(128);
  const state: State = {
    h: IV.slice(),
    t: 0,
    buffer,
    view: new DataView(buffer.buffer),
    fill: 0,
    outlen,
  };

  const keyLength = key ? key.length : 0;
  state.h[0] = (state.h[0] ^ 0x01010000 ^ (keyLength << 8) ^ outlen) >>> 0;

  if (key && keyLength > 0) {
    update(state, key);
    state.fill = 128;
  }

  return state;
}

function update(state: State, input: Uint8Array) {
  for (let i = 0; i < input.length; i += 1) {
    if (state.fill === 128) {
      state.t += 128;
      compress(state, false);
      state.fill = 0;
    }
    state.buffer[state.fill] = input[i];
    state.fill += 1;
  }
}

function digest(state: State): Uint8Array {
  state.t += state.fill;
  while (state.fill < 128) {
    state.buffer[state.fill] = 0;
    state.fill += 1;
  }
  compress(state, true);

  const out = new Uint8Array(state.outlen);
  for (let i = 0; i < state.outlen; i += 1) {
    out[i] = (state.h[i >> 2] >> (8 * (i & 3))) & 0xff;
  }
  return out;
}

export function blake2b(
  input: Uint8Array,
  outlen = 64,
  key: Uint8Array | null = null,
): Uint8Array {
  if (outlen < 1 || outlen > 64) throw new Error('blake2b: bad output length');

  const state = create(outlen, key);
  update(state, input);
  return digest(state);
}

export function blake2bLong(input: Uint8Array, outlen: number): Uint8Array {
  const prefix = new Uint8Array(4);
  new DataView(prefix.buffer).setUint32(0, outlen, true);

  const seeded = new Uint8Array(prefix.length + input.length);
  seeded.set(prefix, 0);
  seeded.set(input, prefix.length);

  if (outlen <= 64) return blake2b(seeded, outlen);

  const out = new Uint8Array(outlen);
  const rounds = Math.ceil(outlen / 32) - 2;

  let block = blake2b(seeded, 64);
  out.set(block.subarray(0, 32), 0);
  let produced = 32;

  for (let i = 1; i < rounds; i += 1) {
    block = blake2b(block, 64);
    out.set(block.subarray(0, 32), produced);
    produced += 32;
  }

  out.set(blake2b(block, outlen - 32 * rounds), produced);
  return out;
}
