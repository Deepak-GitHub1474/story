import Link from 'next/link';

export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-2xl flex-col justify-center px-6 py-16">
      <p className="text-sm font-semibold tracking-[0.4em] text-text-muted">STORY</p>

      <h1 className="mt-8 text-4xl leading-tight font-bold text-balance sm:text-5xl">
        Say the thing you cannot say anywhere else.
      </h1>

      <p className="mt-6 text-lg leading-relaxed text-text-secondary">
        No email. No phone. No real name. Every account is unknown to every other
        account, permanently and by design — because you cannot leak what was never
        collected.
      </p>

      <div className="mt-10 flex flex-wrap gap-3">
        <Link
          href="/signin"
          className="rounded-xl bg-accent px-6 py-3 font-semibold text-accent-text transition-opacity hover:opacity-90"
        >
          Sign in
        </Link>
        <Link
          href="/signup"
          className="rounded-xl border border-border px-6 py-3 font-semibold transition-colors hover:bg-surface"
        >
          Create an account
        </Link>
      </div>

      <p className="mt-16 text-sm text-text-muted">
        Reading a shared story? Open the link you were sent — no account needed.
      </p>
    </main>
  );
}
