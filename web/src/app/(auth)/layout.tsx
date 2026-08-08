import Link from 'next/link';

const NOTES = [
  ['No email, no phone', 'The form is a username and a password. That is all of it.'],
  ['Nothing to hand over', 'We hold no address to leak and no number to trace.'],
  ['Yours to close', 'Delete the account and the writing goes with it.'],
];

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-dvh bg-bg text-text-primary lg:grid lg:grid-cols-12">
      <aside className="relative hidden lg:col-span-5 lg:flex lg:flex-col lg:justify-between lg:border-r lg:border-border lg:bg-surface lg:px-12 lg:py-12">
        <Link
          href="/"
          className="rise text-[length:var(--text-caption)] font-medium tracking-[0.42em] text-text-muted transition-colors hover:text-text-secondary"
        >
          STORY
        </Link>

        <div>
          <p
            className="rise font-editorial text-[clamp(1.6rem,2.4vw,2.15rem)] leading-[1.35] font-medium text-balance"
            style={{ animationDelay: '120ms' }}
          >
            Somewhere to put the good day nobody asked about, and the thing you
            have never said out loud.
          </p>

          <dl className="mt-12 space-y-7">
            {NOTES.map(([title, body], index) => (
              <div
                key={title}
                className="rise"
                style={{ animationDelay: `${240 + index * 90}ms` }}
              >
                <dt className="flex items-baseline gap-4">
                  <span className="text-[length:var(--text-caption)] text-text-muted tabular-nums">
                    {String(index + 1).padStart(2, '0')}
                  </span>
                  <span className="text-[length:var(--text-label)] font-medium">
                    {title}
                  </span>
                </dt>
                <dd className="mt-1 pl-9 text-[length:var(--text-label)] leading-relaxed text-text-secondary">
                  {body}
                </dd>
              </div>
            ))}
          </dl>
        </div>

        <p className="text-[length:var(--text-caption)] text-text-muted">
          Written by people who will never be named.
        </p>
      </aside>

      <div className="flex min-h-dvh flex-col px-6 py-10 sm:px-10 lg:col-span-7 lg:py-12">
        <Link
          href="/"
          className="text-[length:var(--text-caption)] font-medium tracking-[0.42em] text-text-muted transition-colors hover:text-text-secondary lg:hidden"
        >
          STORY
        </Link>

        <div className="flex flex-1 flex-col justify-center py-10">
          <div className="rise mx-auto w-full max-w-[26rem]">{children}</div>
        </div>
      </div>
    </div>
  );
}
