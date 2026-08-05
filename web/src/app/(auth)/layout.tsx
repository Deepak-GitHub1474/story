import Link from 'next/link';

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-[560px] flex-col px-6 py-10">
      <Link
        href="/"
        className="text-xs font-semibold tracking-[0.4em] text-text-muted transition-colors hover:text-text-secondary"
      >
        STORY
      </Link>
      <div className="flex flex-1 flex-col justify-center py-10">{children}</div>
    </div>
  );
}
