import Link from 'next/link';
import { SignOutButton } from '@/components/SignOutButton';
import { requireStaff } from '@/lib/server/guard';

export default async function DashLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const staff = await requireStaff();
  const isAdmin = staff.role !== 'moderator';

  return (
    <div className="min-h-dvh">
      <header className="border-b border-border bg-surface">
        <div className="mx-auto flex h-16 max-w-6xl items-center gap-6 px-4 sm:px-6">
          <span className="text-xs font-semibold tracking-[0.35em]">STORY ADMIN</span>

          <nav className="flex flex-1 items-center gap-1 overflow-x-auto">
            <NavLink href="/queue" label="Queue" />
            {isAdmin ? <NavLink href="/users" label="Accounts" /> : null}
            {isAdmin ? <NavLink href="/audit" label="Audit" /> : null}
          </nav>

          <span className="hidden text-[length:var(--text-caption)] text-text-muted sm:inline">
            @{staff.username} · {staff.role}
          </span>
          <SignOutButton />
        </div>
      </header>

      <main className="mx-auto w-full max-w-6xl px-4 py-8 sm:px-6">{children}</main>
    </div>
  );
}

function NavLink({ href, label }: { href: string; label: string }) {
  return (
    <Link
      href={href}
      className="rounded-[length:var(--radius-sm)] px-3 py-2 text-[length:var(--text-label)] text-text-secondary transition-colors hover:bg-surface-raised hover:text-text-primary"
    >
      {label}
    </Link>
  );
}
