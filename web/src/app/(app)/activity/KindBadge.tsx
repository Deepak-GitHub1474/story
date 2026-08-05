const GLYPHS: Record<string, { path: string; tone: string; label: string }> = {
  like: {
    path: 'M12 20.5 4.4 13a4.6 4.6 0 0 1 6.5-6.5l1.1 1.1 1.1-1.1A4.6 4.6 0 0 1 19.6 13Z',
    tone: 'bg-danger',
    label: 'Like',
  },
  comment: {
    path: 'M21 11.5a8.4 8.4 0 0 1-9 8.4 9 9 0 0 1-3.9-.9L3 20.5l1.6-4.6A8.4 8.4 0 1 1 21 11.5Z',
    tone: 'bg-accent',
    label: 'Comment',
  },
  reply: {
    path: 'M9 14 4 9l5-5M4 9h9a7 7 0 0 1 7 7v4',
    tone: 'bg-accent',
    label: 'Reply',
  },
  follow: {
    path: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM20 8v6M23 11h-6',
    tone: 'bg-success',
    label: 'Follow',
  },
};

export function KindBadge({ kind }: { kind: string }) {
  const glyph = GLYPHS[kind];
  if (!glyph) return null;

  return (
    <span
      aria-label={glyph.label}
      className={`absolute -right-1 -bottom-1 inline-flex size-5 items-center justify-center rounded-full border-2 border-bg ${glyph.tone}`}
    >
      <svg
        viewBox="0 0 24 24"
        aria-hidden="true"
        className="size-2.5 text-accent-text"
        fill={kind === 'like' ? 'currentColor' : 'none'}
        stroke="currentColor"
        strokeWidth="2.5"
      >
        <path d={glyph.path} />
      </svg>
    </span>
  );
}
