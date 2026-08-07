const HEX = '0123456789abcdef';

function seed() {
  const bytes = new Uint8Array(8);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (byte) => HEX[byte >> 4] + HEX[byte & 15]).join('');
}

export function newAvatarSeeds(count: number, keep?: string) {
  const seeds = new Set<string>();
  if (keep) seeds.add(keep);
  while (seeds.size < count) seeds.add(seed());
  return [...seeds];
}
