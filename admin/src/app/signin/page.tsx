import type { Metadata } from 'next';
import { SignInForm } from './SignInForm';

export const metadata: Metadata = { title: 'Sign in' };

const NOTES = [
  ['Every action is logged', 'Append-only, hash-chained, and readable by the person it touched.'],
  ['Staff accounts only', 'A role below moderator is refused at the door.'],
  ['Least privilege', 'Escrow release needs super_admin and an authenticator code.'],
];

export default function AdminSignInPage() {
  return (
    <div className="min-h-dvh bg-bg text-text-primary lg:grid lg:grid-cols-12">
      <aside className="relative hidden lg:col-span-5 lg:flex lg:flex-col lg:justify-between lg:border-r lg:border-border lg:bg-surface lg:px-12 lg:py-12">
        <span className="text-[length:var(--text-caption)] font-semibold tracking-[0.3em] text-text-muted">
          STORY <span className="text-text-muted/60">ADMIN</span>
        </span>

        <div>
          <p className="font-editorial text-[clamp(1.6rem,2.4vw,2.15rem)] leading-[1.35] font-semibold tracking-[var(--tracking-title)] text-balance">
            The tools that touch someone&rsquo;s account, and the log that keeps them
            honest.
          </p>

          <dl className="mt-12 space-y-7">
            {NOTES.map(([title, body], index) => (
              <div key={title}>
                <dt className="flex items-baseline gap-4">
                  <span className="text-[length:var(--text-caption)] text-text-muted tabular-nums">
                    {String(index + 1).padStart(2, '0')}
                  </span>
                  <span className="text-[length:var(--text-label)] font-medium">{title}</span>
                </dt>
                <dd className="mt-1 pl-9 text-[length:var(--text-label)] leading-relaxed text-text-secondary">
                  {body}
                </dd>
              </div>
            ))}
          </dl>
        </div>

        <p className="text-[length:var(--text-caption)] text-text-muted">
          Staff hold an account separate from their own.
        </p>
      </aside>

      <div className="flex min-h-dvh flex-col px-5 py-10 sm:px-10 lg:col-span-7 lg:py-12">
        <span className="text-[length:var(--text-caption)] font-semibold tracking-[0.3em] text-text-muted lg:hidden">
          STORY <span className="text-text-muted/60">ADMIN</span>
        </span>

        <div className="flex flex-1 flex-col justify-center py-10">
          <div className="mx-auto w-full max-w-[26rem]">
            <h1 className="font-editorial text-[length:var(--text-title)] leading-tight font-semibold tracking-[var(--tracking-title)]">
              Staff sign in
            </h1>
            <p className="mt-2 leading-relaxed text-text-secondary">
              Every action here is written to an append-only audit log that the affected
              person can read.
            </p>

            <div className="mt-8">
              <SignInForm />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
