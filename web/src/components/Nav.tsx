'use client';

import { useEffect, useState } from 'react';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cn } from '@/lib/cn';
import { DESKTOP_LINKS, MOBILE_ACTIONS, NAV_LINKS, type NavItem } from '@/components/nav/const';
import { Icon } from '@/components/ui/Icon';
import { Avatar } from '@/components/Avatar';

function Count({ value, tone }: { value: number; tone: 'accent' | 'danger' }) {
  return (
    <span
      className={cn(
        'numeric ml-1.5 inline-flex h-4 min-w-4 items-center justify-center rounded-[length:var(--radius-pill)] px-1',
        'text-[length:var(--text-micro)] font-semibold',
        tone === 'accent' ? 'bg-accent-strong text-accent-text' : 'bg-danger text-bg',
      )}
    >
      {value > 99 ? '99+' : value}
    </span>
  );
}

export function Nav({
  unread,
  username,
  avatarSeed,
}: {
  unread: number;
  username: string;
  avatarSeed: string;
}) {
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
            className="font-editorial shrink-0 text-[20px] leading-none font-medium tracking-[0.25em] text-text-primary"
          >
            STORY
          </Link>

          <ul className="hidden flex-1 items-center gap-0.5 sm:flex">
            {DESKTOP_LINKS.map((link) => {
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

          <div className="flex flex-1 items-center justify-end gap-1 sm:flex-none sm:gap-3">
            {MOBILE_ACTIONS.map((action) => (
              <Link
                key={action.href}
                href={action.href}
                aria-label={action.label}
                className="inline-grid size-11 place-items-center rounded-full text-text-primary sm:hidden"
              >
                <Icon name={action.icon} />
              </Link>
            ))}

            <Link
              href="/compose"
              className={cn(
                'hidden h-9 items-center rounded-[length:var(--radius-md)] border border-transparent bg-accent-strong px-4 sm:inline-flex',
                'text-[length:var(--text-caption)] font-medium tracking-[var(--tracking-label)] text-accent-text',
                'transition-[filter] duration-[var(--motion-fast)] hover:brightness-108',
              )}
            >
              Write
            </Link>
            <Link
              href="/profile"
              aria-label={`Your profile, @${username}`}
              title={`@${username}`}
              className={cn(
                'ml-1 inline-grid size-9 shrink-0 place-items-center rounded-full sm:ml-0',
                'transition-opacity duration-[var(--motion-fast)] hover:opacity-80',
                pathname.startsWith('/profile') || pathname.startsWith('/settings')
                  ? 'opacity-100'
                  : 'opacity-85',
              )}
            >
              <Avatar seed={avatarSeed} size={32} />
            </Link>
          </div>
        </nav>
      </header>

      <nav className="fixed inset-x-0 bottom-0 z-30 border-t-[0.6px] border-border bg-bg pb-[env(safe-area-inset-bottom)] sm:hidden">
        <ul className="grid h-[62px] grid-cols-5 items-center">
          {NAV_LINKS.slice(0, 2).map((link) => (
            <BottomItem
              key={link.href}
              link={link}
              isActive={pathname.startsWith(link.href)}
              count={countFor(link.href)}
            />
          ))}

          <li>
            <Link
              href="/compose"
              aria-label="Write"
              className="flex h-[62px] flex-col items-center justify-center gap-[3px]"
            >
              <span
                className={cn(
                  'grid size-9 place-items-center rounded-full bg-accent-strong text-accent-text',
                  'transition-transform duration-[var(--motion-fast)] active:scale-90',
                )}
              >
                <Icon name="plus" />
              </span>
              <span className="text-[10px] leading-[1.1] font-medium tracking-[0.2px] text-text-secondary">
                Write
              </span>
            </Link>
          </li>

          {NAV_LINKS.slice(2).map((link) => (
            <BottomItem
              key={link.href}
              link={link}
              isActive={pathname.startsWith(link.href)}
              count={countFor(link.href)}
            />
          ))}
        </ul>
      </nav>
    </>
  );
}

function BottomItem({
  link,
  isActive,
  count,
}: {
  link: NavItem;
  isActive: boolean;
  count: { value: number; tone: 'accent' | 'danger' } | null;
}) {
  return (
    <li>
      <Link
        href={link.href}
        aria-current={isActive ? 'page' : undefined}
        className={cn(
          'flex h-[62px] flex-col items-center justify-center gap-[3px] text-center',
          'transition-colors duration-[var(--motion-fast)]',
          isActive ? 'text-accent' : 'text-text-secondary',
        )}
      >
        <span className="relative grid size-[26px] place-items-center">
          <Icon name={link.icon} size={26} />
          {count ? (
            <span className="absolute -top-px -right-0.5 size-2 rounded-full border-[1.5px] border-bg bg-danger" />
          ) : null}
        </span>
        <span
          className={cn(
            'text-[10px] leading-[1.1] tracking-[0.2px]',
            isActive ? 'font-semibold' : 'font-medium',
          )}
        >
          {link.label}
        </span>
      </Link>
    </li>
  );
}
