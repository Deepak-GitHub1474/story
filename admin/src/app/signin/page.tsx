import type { Metadata } from 'next';
import { SignInForm } from './SignInForm';

export const metadata: Metadata = { title: 'Sign in' };

export default function AdminSignInPage() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-sm flex-col justify-center px-6">
      <p className="text-xs font-medium tracking-[0.4em] text-text-muted">
        STORY ADMIN
      </p>
      <h1 className="mt-6 text-[length:var(--text-title)] font-medium">Staff sign in</h1>
      <p className="mt-2 text-[length:var(--text-label)] leading-relaxed text-text-secondary">
        Staff accounts only. Every action here is written to an append-only audit log
        that the affected person can read.
      </p>
      <div className="mt-8">
        <SignInForm />
      </div>
    </main>
  );
}
