import Link from 'next/link';
import { cn } from '@/lib/cn';

const BASE =
  'inline-flex h-8 shrink-0 items-center rounded-[length:var(--radius-md)] border px-3 ' +
  'text-[length:var(--text-caption)] whitespace-nowrap transition-colors duration-[var(--motion-fast)]';

const TONES = {
  on: 'border-accent bg-accent font-medium text-accent-text',
  off: 'border-border text-text-secondary hover:border-border-strong hover:text-text-primary',
} as const;

export function ChipLink({
  href,
  isActive = false,
  children,
}: {
  href: string;
  isActive?: boolean;
  children: React.ReactNode;
}) {
  return (
    <Link
      href={href}
      aria-current={isActive ? 'page' : undefined}
      className={cn(BASE, isActive ? TONES.on : TONES.off)}
    >
      {children}
    </Link>
  );
}
