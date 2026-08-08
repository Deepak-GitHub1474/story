import Link from 'next/link';

export default function NotFound() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-lg flex-col justify-center px-6 text-center">
      <p className="text-xs font-medium tracking-[0.4em] text-text-muted">STORY</p>
      <h1 className="mt-6 text-[length:var(--text-title)] font-medium">
        This page is not here
      </h1>
      <p className="mt-2 leading-relaxed text-text-secondary">
        It may have been unpublished, deleted, or never existed. We do not say which.
      </p>
      <Link
        href="/"
        className="mt-8 self-center rounded-[length:var(--radius-md)] border border-border px-6 py-3 font-medium transition-colors hover:bg-surface"
      >
        Go home
      </Link>
    </main>
  );
}
