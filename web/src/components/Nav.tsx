'use client';

import { useEffect, useState } from 'react';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cn } from '@/lib/cn';

const LINKS = [
  { href: '/feed', label: 'Stories' },
  { href: '/communities', label: 'Communities' },
  { href: '/search', label: 'Search' },
  { href: '/activity', label: 'Activity' },
  { href: '/chats', label: 'Messages' },
];

export function Nav({ unread, username }: { unread: number; username: string }) {
  const [chatUnread, setChatUnread] = useState(0);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      const response = await fetch('/api/chat?unread=1');
      const data = (await response.json()) as {
        unread: number;
        requests: number;
      } | null;
      if (!cancelled && data) setChatUnread(data.unread + data.requests);
    }

    void load();
    const timer = setInterval(load, 20000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, []);

  const pathname = usePathname();

  return (
    <header className="sticky top-0 z-20 border-b border-border bg-bg/85 backdrop-blur">
      <nav className="mx-auto flex h-16 max-w-5xl items-center gap-1 px-4 sm:px-6">
        <Link
          href="/feed"
          className="mr-4 shrink-0 text-xs font-medium tracking-[0.35em] text-text-primary"
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
                      ? 'font-medium text-text-primary'
                      : 'text-text-muted hover:text-text-secondary',
                  )}
                >
                  {link.label}
                  {link.href === '/chats' && chatUnread > 0 ? (
                    <span className="ml-1.5 rounded-[length:var(--radius-pill)] bg-accent px-1.5 text-[length:var(--text-caption)] font-medium text-accent-text">
                      {chatUnread}
                    </span>
                  ) : null}
                  {link.href === '/chats' && chatUnread > 0 ? (
                    <span className="ml-1.5 rounded-[length:var(--radius-pill)] bg-accent px-1.5 text-[length:var(--text-caption)] font-medium text-accent-text">
                      {chatUnread > 99 ? '99+' : chatUnread}
                    </span>
                  ) : null}
                  {link.href === '/activity' && unread > 0 ? (
                    <span className="ml-1.5 inline-flex min-w-4 items-center justify-center rounded-[length:var(--radius-pill)] bg-danger px-1 text-[10px] font-medium text-bg">
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
            className="rounded-[length:var(--radius-md)] border border-accent bg-accent px-4 py-2 text-[length:var(--text-label)] font-medium text-accent-text transition-opacity hover:opacity-90"
          >
            Write
          </Link>
          <Link
            href="/profile"
            className={cn(
              'rounded-[length:var(--radius-sm)] px-3 py-2 text-[length:var(--text-label)] transition-colors',
              pathname.startsWith('/profile') || pathname.startsWith('/settings')
                ? 'font-medium text-text-primary'
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
