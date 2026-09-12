'use client';

import { useEffect, useState } from 'react';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cn } from '@/lib/cn';
import { NAV_LINKS } from '@/components/nav/const';

function Count({ value, tone }: { value: number; tone: 'accent' | 'danger' }) {
  return (
    <span
      className={cn(
        'numeric ml-1.5 inline-flex h-4 min-w-4 items-center justify-center rounded-[length:var(--radius-pill)] px-1',
        'text-[length:var(--text-micro)] font-semibold',
        tone === 'accent' ? 'bg-accent text-accent-text' : 'bg-danger text-bg',
      )}
    >
      {value > 99 ? '99+' : value}
    </span>
  );
}

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

  function countFor(href: string) {
    if (href === '/chats' && chatUnread > 0) return { value: chatUnread, tone: 'accent' as const };
    if (href === '/activity' && unread > 0) return { value: unread, tone: 'danger' as const };
    return null;
  }

  return (
    <>
      <header className="sticky top-0 z-30 border-b border-border bg-bg/80 backdrop-blur-md">
        <nav className="mx-auto flex h-16 max-w-5xl items-center gap-6 px-5 sm:px-8">
          <Link
            href="/feed"
            className="font-editorial shrink-0 text-[length:var(--text-heading)] leading-none font-semibold tracking-[0.16em] text-text-primary"
          >
            STORY
          </Link>

          <ul className="hidden flex-1 items-center gap-0.5 sm:flex">
            {NAV_LINKS.map((link) => {
              const isActive = pathname.startsWith(link.href);
              const count = countFor(link.href);
              return (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    aria-current={isActive ? 'page' : undefined}
                    className={cn(
                      'relative inline-flex items-center px-3 py-5 text-[length:var(--text-label)]',
                      'whitespace-nowrap transition-colors duration-[var(--motion-fast)]',
                      'after:absolute after:inset-x-3 after:bottom-0 after:h-px after:origin-left',
                      'after:transition-transform after:duration-[var(--motion-base)]',
                      'after:ease-[var(--ease-out-quint)] after:bg-accent',
                      isActive
                        ? 'text-text-primary after:scale-x-100'
                        : 'text-text-muted after:scale-x-0 hover:text-text-secondary',
                    )}
                  >
                    {link.label}
                    {count ? <Count value={count.value} tone={count.tone} /> : null}
                  </Link>
                </li>
              );
            })}
          </ul>

          <div className="flex flex-1 items-center justify-end gap-2 sm:flex-none sm:gap-3">
            <Link
              href="/compose"
              className={cn(
                'inline-flex h-9 items-center rounded-[length:var(--radius-md)] border border-accent bg-accent px-4',
                'text-[length:var(--text-caption)] font-medium tracking-[var(--tracking-label)] text-accent-text',
                'transition-[filter] duration-[var(--motion-fast)] hover:brightness-108',
              )}
            >
              Write
            </Link>
            <Link
              href="/profile"
              aria-label={`Your profile, @${username}`}
              className={cn(
                'inline-flex h-9 max-w-36 items-center truncate rounded-[length:var(--radius-md)] px-2.5',
                'text-[length:var(--text-caption)] transition-colors duration-[var(--motion-fast)]',
                pathname.startsWith('/profile') || pathname.startsWith('/settings')
                  ? 'bg-surface text-text-primary'
                  : 'text-text-muted hover:bg-surface hover:text-text-secondary',
              )}
            >
              @{username}
            </Link>
          </div>
        </nav>
      </header>

      <nav className="fixed inset-x-0 bottom-0 z-30 border-t border-border bg-bg/92 pb-[env(safe-area-inset-bottom)] backdrop-blur-md sm:hidden">
        <ul className="grid grid-cols-5">
          {NAV_LINKS.map((link) => {
            const isActive = pathname.startsWith(link.href);
            const count = countFor(link.href);
            return (
              <li key={link.href}>
                <Link
                  href={link.href}
                  aria-current={isActive ? 'page' : undefined}
                  className={cn(
                    'flex h-14 flex-col items-center justify-center gap-0.5 text-center',
                    'text-[length:var(--text-micro)] tracking-[0.04em] transition-colors',
                    isActive ? 'text-accent' : 'text-text-muted',
                  )}
                >
                  <span className="relative">
                    {link.label}
                    {count ? (
                      <span
                        className={cn(
                          'absolute -top-1 -right-2.5 size-1.5 rounded-full',
                          count.tone === 'accent' ? 'bg-accent' : 'bg-danger',
                        )}
                      />
                    ) : null}
                  </span>
                  <span
                    className={cn(
                      'h-px w-5 transition-opacity duration-[var(--motion-base)]',
                      isActive ? 'bg-accent opacity-100' : 'opacity-0',
                    )}
                  />
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>
    </>
  );
}
