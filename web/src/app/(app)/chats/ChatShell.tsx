'use client';

import { usePathname } from 'next/navigation';
import { cn } from '@/lib/cn';

export function ChatShell({
  list,
  children,
}: {
  list: React.ReactNode;
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const hasThread = pathname !== '/chats';

  return (
    <div className="grid gap-0 lg:grid-cols-[20rem_1fr] lg:gap-8">
      <aside
        className={cn(
          'min-w-0 lg:block lg:border-r lg:border-border lg:pr-8',
          hasThread ? 'hidden' : 'block',
        )}
      >
        {list}
      </aside>

      <section className={cn('min-w-0', hasThread ? 'block' : 'hidden lg:block')}>
        {children}
      </section>
    </div>
  );
}
