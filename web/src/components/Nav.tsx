'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cn } from '@/lib/cn';

const LINKS = [
  { href: '/feed', label: 'Stories' },
  { href: '/communities', label: 'Communities' },
  { href: '/search', label: 'Search' },
  { href: '/activity', label: 'Activity' },
];

export function Nav({ unread, username }: { unread: number; username: string }) {
  const pathname = usePathname();

  return (
    <header className="sticky top-0 z-20 border-b border-border bg-bg/85 backdrop-blur">
      <nav className="mx-auto flex h-16 max-w-5xl items-center gap-1 px-4 sm:px-6">
        <Link
          href="/feed"
          className="mr-4 shrink-0 text-xs font-semibold tracking-[0.35em] text-text-primary"
        >
          STORY
        </Link>

        <ul className="flex flex-1 items-center gap-1 overflow-x-auto">
          {LINKS.map((link) => {
            const isActive = pathname.startsWith(link.href);
            return (
              <li key={link.href}>
                <Link
                  href={link.href}
                  aria-current={isActive ? 'page' : undefined}
                  className={cn(
                    'relative inline-flex items-center rounded-[length:var(--radius-sm)] px-3 py-2',
                    'text-[length:var(--text-label)] whitespace-nowrap transition-colors',
                    isActive
                      ? 'font-semibold text-text-primary'
                      : 'text-text-muted hover:text-text-secondary',
                  )}
                >
                  {link.label}
                  {link.href === '/activity' && unread > 0 ? (
                    <span className="ml-1.5 inline-flex min-w-4 items-center justify-center rounded-[length:var(--radius-pill)] bg-danger px-1 text-[10px] font-bold text-bg">
                      {unread > 99 ? '99+' : unread}
                    </span>
                  ) : null}
                </Link>
              </li>
            );
          })}
        </ul>

        <div className="flex shrink-0 items-center gap-2">
          <Link
            href="/compose"
            className="rounded-[length:var(--radius-md)] border border-accent bg-accent px-4 py-2 text-[length:var(--text-label)] font-semibold text-accent-text transition-opacity hover:opacity-90"
          >
            Write
          </Link>
          <Link
            href="/profile"
            className={cn(
              'rounded-[length:var(--radius-sm)] px-3 py-2 text-[length:var(--text-label)] transition-colors',
              pathname.startsWith('/profile') || pathname.startsWith('/settings')
                ? 'font-semibold text-text-primary'
                : 'text-text-muted hover:text-text-secondary',
            )}
          >
            @{username}
          </Link>
        </div>
      </nav>
    </header>
  );
}
