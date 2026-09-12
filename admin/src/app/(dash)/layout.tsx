import Link from 'next/link';
import { SignOutButton } from '@/components/SignOutButton';
import { linksFor } from '@/components/nav/const';
import { requireStaff } from '@/lib/server/guard';

export default async function DashLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const staff = await requireStaff();
  const links = linksFor(staff.role);

  return (
    <div className="min-h-dvh">
      <header className="sticky top-0 z-30 border-b border-border bg-bg/92 backdrop-blur-md">
        <div className="mx-auto flex h-14 max-w-6xl items-center gap-5 px-4 sm:px-6">
          <span className="shrink-0 text-[length:var(--text-micro)] font-semibold tracking-[0.3em] text-text-primary">
            STORY
            <span className="ml-2 text-text-muted">ADMIN</span>
          </span>

          <nav className="-mx-1 flex flex-1 items-center gap-0.5 overflow-x-auto px-1">
            {links.map((link) => (
              <NavLink key={link.href} href={link.href} label={link.label} />
            ))}
          </nav>

          <span className="hidden shrink-0 items-center gap-2 text-[length:var(--text-caption)] text-text-muted sm:flex">
            <span className="mono">@{staff.username}</span>
            <span className="rounded-[length:var(--radius-sm)] border border-border px-1.5 py-0.5 text-[length:var(--text-micro)] tracking-[0.08em] uppercase">
              {staff.role.replace('_', ' ')}
            </span>
          </span>

          <SignOutButton />
        </div>
      </header>

      <main className="mx-auto w-full max-w-6xl px-4 py-8 sm:px-6 sm:py-10">{children}</main>
    </div>
  );
}

function NavLink({ href, label }: { href: string; label: string }) {
  return (
    <Link
      href={href}
      className="rounded-[length:var(--radius-md)] px-2.5 py-1.5 text-[length:var(--text-label)] whitespace-nowrap text-text-secondary transition-colors duration-[var(--motion-fast)] hover:bg-surface hover:text-text-primary"
    >
      {label}
    </Link>
  );
}
