const PALETTE = [
  '#9B8CFF',
  '#7BD88F',
  '#FFB86B',
  '#6BC5FF',
  '#FF8AB8',
  '#E0C36B',
];

function hashSeed(seed: string): number {
  return [...seed].reduce((acc, char) => (acc * 31 + char.charCodeAt(0)) & 0x7fffffff, 7);
}

export function Avatar({ seed, size = 40 }: { seed: string; size?: number }) {
  const hash = hashSeed(seed);
  const base = PALETTE[hash % PALETTE.length];
  const accent = PALETTE[Math.floor(hash / 7) % PALETTE.length];
  const letter = String.fromCharCode(65 + (hash % 26));

  return (
    <span
      aria-hidden="true"
      className="inline-flex shrink-0 items-center justify-center rounded-full border border-border font-bold text-[#0B0D12]"
      style={{
        width: size,
        height: size,
        fontSize: size * 0.4,
        backgroundImage: `linear-gradient(135deg, ${base}, ${accent})`,
      }}
    >
      {letter}
    </span>
  );
}
