import { blake2b, blake2bLong } from './blake2b';

const BLOCK_BYTES = 1024;
const BLOCK_U32 = 256;
const ADDRESSES_IN_BLOCK = 128;
const SYNC_POINTS = 4;
const TYPE_ARGON2ID = 2;
const VERSION = 0x13;

export type Argon2idParams = {
  password: Uint8Array;
  salt: Uint8Array;
  memoryKib: number;
  iterations: number;
  parallelism: number;
  hashLength: number;
  secret?: Uint8Array;
  associatedData?: Uint8Array;
};

function u32le(value: number): Uint8Array {
  const out = new Uint8Array(4);
  new DataView(out.buffer).setUint32(0, value >>> 0, true);
  return out;
}

function concat(parts: Uint8Array[]): Uint8Array {
  let length = 0;
  for (const part of parts) length += part.length;

  const out = new Uint8Array(length);
  let offset = 0;
  for (const part of parts) {
    out.set(part, offset);
    offset += part.length;
  }
  return out;
}

function mulhi(a: number, b: number): number {
  const ah = a >>> 16;
  const al = a & 0xffff;
  const bh = b >>> 16;
  const bl = b & 0xffff;

  const t0 = al * bl;
  const t1 = ah * bl + Math.floor(t0 / 0x10000);
  const t2 = al * bh + (t1 & 0xffff);

  return ah * bh + Math.floor(t1 / 0x10000) + Math.floor(t2 / 0x10000);
}

function add64(a: Uint32Array, i: number, j: number) {
  const low = a[i] + a[j];
  a[i] = low >>> 0;
  a[i + 1] = (a[i + 1] + a[j + 1] + (low >= 0x100000000 ? 1 : 0)) >>> 0;
}

function blaMka(a: Uint32Array, i: number, j: number) {
  const xlo = a[i];
  const ylo = a[j];

  const xh = xlo >>> 16;
  const xl = xlo & 0xffff;
  const yh = ylo >>> 16;
  const yl = ylo & 0xffff;

  const t0 = xl * yl;
  const t1 = xh * yl + Math.floor(t0 / 0x10000);
  const t2 = xl * yh + (t1 & 0xffff);

  const mlo = (((t2 & 0xffff) << 16) | (t0 & 0xffff)) >>> 0;
  const mhi = (xh * yh + Math.floor(t1 / 0x10000) + Math.floor(t2 / 0x10000)) >>> 0;

  const doubledLo = (mlo << 1) >>> 0;
  const doubledHi = ((mhi << 1) | (mlo >>> 31)) >>> 0;

  add64(a, i, j);

  const low = a[i] + doubledLo;
  a[i] = low >>> 0;
  a[i + 1] = (a[i + 1] + doubledHi + (low >= 0x100000000 ? 1 : 0)) >>> 0;
}

function rotr64(a: Uint32Array, i: number, bits: number) {
  const lo = a[i];
  const hi = a[i + 1];

  if (bits === 32) {
    a[i] = hi;
    a[i + 1] = lo;
    return;
  }

  if (bits < 32) {
    a[i] = ((lo >>> bits) | (hi << (32 - bits))) >>> 0;
    a[i + 1] = ((hi >>> bits) | (lo << (32 - bits))) >>> 0;
    return;
  }

  const shift = bits - 32;
  a[i] = ((hi >>> shift) | (lo << (32 - shift))) >>> 0;
  a[i + 1] = ((lo >>> shift) | (hi << (32 - shift))) >>> 0;
}

function xor64(a: Uint32Array, i: number, j: number) {
  a[i] = (a[i] ^ a[j]) >>> 0;
  a[i + 1] = (a[i + 1] ^ a[j + 1]) >>> 0;
}

function quarter(a: Uint32Array, x: number, y: number, z: number, w: number) {
  blaMka(a, x, y);
  xor64(a, w, x);
  rotr64(a, w, 32);

  blaMka(a, z, w);
  xor64(a, y, z);
  rotr64(a, y, 24);

  blaMka(a, x, y);
  xor64(a, w, x);
  rotr64(a, w, 16);

  blaMka(a, z, w);
  xor64(a, y, z);
  rotr64(a, y, 63);
}

function round(a: Uint32Array, o: Int32Array) {
  quarter(a, o[0], o[4], o[8], o[12]);
  quarter(a, o[1], o[5], o[9], o[13]);
  quarter(a, o[2], o[6], o[10], o[14]);
  quarter(a, o[3], o[7], o[11], o[15]);
  quarter(a, o[0], o[5], o[10], o[15]);
  quarter(a, o[1], o[6], o[11], o[12]);
  quarter(a, o[2], o[7], o[8], o[13]);
  quarter(a, o[3], o[4], o[9], o[14]);
}

const ROW_OFFSETS: Int32Array[] = [];
for (let i = 0; i < 8; i += 1) {
  const offsets = new Int32Array(16);
  for (let j = 0; j < 16; j += 1) offsets[j] = i * 32 + j * 2;
  ROW_OFFSETS.push(offsets);
}

const COL_OFFSETS: Int32Array[] = [];
for (let i = 0; i < 8; i += 1) {
  const offsets = new Int32Array(16);
  for (let j = 0; j < 8; j += 1) {
    offsets[j * 2] = j * 32 + i * 4;
    offsets[j * 2 + 1] = j * 32 + i * 4 + 2;
  }
  COL_OFFSETS.push(offsets);
}

const mixed = new Uint32Array(BLOCK_U32);
const state = new Uint32Array(BLOCK_U32);

function permute() {
  for (let i = 0; i < 8; i += 1) round(state, ROW_OFFSETS[i]);
  for (let i = 0; i < 8; i += 1) round(state, COL_OFFSETS[i]);
}

function fillBlock(
  memory: Uint32Array,
  outOffset: number,
  prevOffset: number,
  refOffset: number,
  withXor: boolean,
) {
  for (let i = 0; i < BLOCK_U32; i += 1) {
    mixed[i] = (memory[prevOffset + i] ^ memory[refOffset + i]) >>> 0;
  }

  state.set(mixed);
  permute();

  if (withXor) {
    for (let i = 0; i < BLOCK_U32; i += 1) {
      memory[outOffset + i] = (memory[outOffset + i] ^ mixed[i] ^ state[i]) >>> 0;
    }
    return;
  }

  for (let i = 0; i < BLOCK_U32; i += 1) {
    memory[outOffset + i] = (mixed[i] ^ state[i]) >>> 0;
  }
}

function fillFromZero(source: Uint32Array, destination: Uint32Array) {
  mixed.set(source);
  state.set(mixed);
  permute();

  for (let i = 0; i < BLOCK_U32; i += 1) {
    destination[i] = (mixed[i] ^ state[i]) >>> 0;
  }
}

function nextAddresses(addressBlock: Uint32Array, inputBlock: Uint32Array) {
  const low = (inputBlock[12] + 1) >>> 0;
  inputBlock[12] = low;
  if (low === 0) inputBlock[13] = (inputBlock[13] + 1) >>> 0;

  fillFromZero(inputBlock, addressBlock);
  fillFromZero(addressBlock, addressBlock);
}

function bytesToBlock(memory: Uint32Array, offset: number, bytes: Uint8Array) {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  for (let i = 0; i < BLOCK_U32; i += 1) {
    memory[offset + i] = view.getUint32(i * 4, true);
  }
}

function indexAlpha(
  pseudoRandom: number,
  slice: number,
  index: number,
  laneLength: number,
  segmentLength: number,
  sameLane: boolean,
  pass: number,
): number {
  let referenceAreaSize: number;

  if (pass === 0) {
    if (slice === 0) {
      referenceAreaSize = index - 1;
    } else if (sameLane) {
      referenceAreaSize = slice * segmentLength + index - 1;
    } else {
      referenceAreaSize = slice * segmentLength + (index === 0 ? -1 : 0);
    }
  } else if (sameLane) {
    referenceAreaSize = laneLength - segmentLength + index - 1;
  } else {
    referenceAreaSize = laneLength - segmentLength + (index === 0 ? -1 : 0);
  }

  const square = mulhi(pseudoRandom, pseudoRandom);
  const relative = referenceAreaSize - 1 - mulhi(referenceAreaSize, square);

  const start =
    pass !== 0 && slice !== SYNC_POINTS - 1 ? (slice + 1) * segmentLength : 0;

  return (start + relative) % laneLength;
}

export function argon2id(params: Argon2idParams): Uint8Array {
  const {
    password,
    salt,
    memoryKib,
    iterations,
    parallelism,
    hashLength,
    secret,
    associatedData,
  } = params;

  const requested = Math.max(memoryKib, 8 * parallelism);
  const segmentLength = Math.floor(requested / (SYNC_POINTS * parallelism));
  const blockCount = segmentLength * SYNC_POINTS * parallelism;
  const laneLength = segmentLength * SYNC_POINTS;

  const h0 = blake2b(
    concat([
      u32le(parallelism),
      u32le(hashLength),
      u32le(memoryKib),
      u32le(iterations),
      u32le(VERSION),
      u32le(TYPE_ARGON2ID),
      u32le(password.length),
      password,
      u32le(salt.length),
      salt,
      u32le(secret ? secret.length : 0),
      secret ?? new Uint8Array(0),
      u32le(associatedData ? associatedData.length : 0),
      associatedData ?? new Uint8Array(0),
    ]),
    64,
  );

  const memory = new Uint32Array(blockCount * BLOCK_U32);

  for (let lane = 0; lane < parallelism; lane += 1) {
    for (let index = 0; index < 2; index += 1) {
      const block = blake2bLong(concat([h0, u32le(index), u32le(lane)]), BLOCK_BYTES);
      bytesToBlock(memory, (lane * laneLength + index) * BLOCK_U32, block);
    }
  }

  const addressBlock = new Uint32Array(BLOCK_U32);
  const inputBlock = new Uint32Array(BLOCK_U32);

  for (let pass = 0; pass < iterations; pass += 1) {
    for (let slice = 0; slice < SYNC_POINTS; slice += 1) {
      for (let lane = 0; lane < parallelism; lane += 1) {
        const dataIndependent = pass === 0 && slice < SYNC_POINTS / 2;

        if (dataIndependent) {
          inputBlock.fill(0);
          inputBlock[0] = pass;
          inputBlock[2] = lane;
          inputBlock[4] = slice;
          inputBlock[6] = blockCount;
          inputBlock[8] = iterations;
          inputBlock[10] = TYPE_ARGON2ID;
        }

        let start = 0;
        if (pass === 0 && slice === 0) {
          start = 2;
          if (dataIndependent) nextAddresses(addressBlock, inputBlock);
        }

        for (let index = start; index < segmentLength; index += 1) {
          const current = lane * laneLength + slice * segmentLength + index;
          const previous =
            current % laneLength === 0 ? current + laneLength - 1 : current - 1;

          let pseudoRandom: number;
          let pseudoRandomHigh: number;

          if (dataIndependent) {
            if (index % ADDRESSES_IN_BLOCK === 0) {
              nextAddresses(addressBlock, inputBlock);
            }
            const position = (index % ADDRESSES_IN_BLOCK) * 2;
            pseudoRandom = addressBlock[position];
            pseudoRandomHigh = addressBlock[position + 1];
          } else {
            pseudoRandom = memory[previous * BLOCK_U32];
            pseudoRandomHigh = memory[previous * BLOCK_U32 + 1];
          }

          const refLane =
            pass === 0 && slice === 0 ? lane : pseudoRandomHigh % parallelism;

          const refIndex = indexAlpha(
            pseudoRandom,
            slice,
            index,
            laneLength,
            segmentLength,
            refLane === lane,
            pass,
          );

          fillBlock(
            memory,
            current * BLOCK_U32,
            previous * BLOCK_U32,
            (refLane * laneLength + refIndex) * BLOCK_U32,
            pass !== 0,
          );
        }
      }
    }
  }

  const final = new Uint32Array(BLOCK_U32);
  for (let lane = 0; lane < parallelism; lane += 1) {
    const offset = (lane * laneLength + laneLength - 1) * BLOCK_U32;
    for (let i = 0; i < BLOCK_U32; i += 1) {
      final[i] = (final[i] ^ memory[offset + i]) >>> 0;
    }
  }

  const finalBytes = new Uint8Array(BLOCK_BYTES);
  const finalView = new DataView(finalBytes.buffer);
  for (let i = 0; i < BLOCK_U32; i += 1) finalView.setUint32(i * 4, final[i], true);

  memory.fill(0);
  return blake2bLong(finalBytes, hashLength);
}
