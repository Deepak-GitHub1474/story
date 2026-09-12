import type { Metadata } from 'next';
import { Card } from '@/components/ui/Surface';
import { SignInForm } from './SignInForm';

export const metadata: Metadata = { title: 'Sign in' };

export default function AdminSignInPage() {
  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-md flex-col justify-center px-5 py-10">
      <p className="text-[length:var(--text-micro)] font-semibold tracking-[0.3em] text-text-muted">
        STORY
        <span className="ml-2 text-text-muted/60">ADMIN</span>
      </p>

      <Card className="mt-5">
        <h1 className="text-[length:var(--text-title)] leading-tight font-semibold tracking-[var(--tracking-title)]">
          Staff sign in
        </h1>
        <p className="mt-2 text-[length:var(--text-label)] leading-relaxed text-text-secondary">
          Staff accounts only. Every action here is written to an append-only audit log
          that the affected person can read.
        </p>

        <div className="mt-7">
          <SignInForm />
        </div>
      </Card>

      <p className="mt-5 text-[length:var(--text-caption)] leading-relaxed text-text-muted">
        There is no impersonation, no password reset, and no way to read anyone&rsquo;s
        vault from here. Those endpoints do not exist for any role.
      </p>
    </main>
  );
}
