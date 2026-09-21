import Link from 'next/link';
import { cn } from '@/lib/cn';

const BASE =
  'inline-flex h-9 shrink-0 items-center gap-1.5 rounded-[length:var(--radius-pill)] px-4 ' +
  'text-[length:var(--text-label)] font-medium whitespace-nowrap ' +
  'transition-colors duration-[var(--motion-fast)] ' +
  'disabled:cursor-not-allowed disabled:opacity-45';

const TONES = {
  on: 'bg-accent-strong text-accent-text',
  off: 'bg-surface-raised text-text-secondary hover:text-text-primary',
} as const;

function classesFor(isActive: boolean, className?: string) {
  return cn(BASE, isActive ? TONES.on : TONES.off, className);
}

export function Chip({
  isActive = false,
  className,
  children,
  ...rest
}: React.ButtonHTMLAttributes<HTMLButtonElement> & { isActive?: boolean }) {
  return (
    <button
      type="button"
      aria-pressed={isActive}
      {...rest}
      className={classesFor(isActive, className)}
    >
      {children}
    </button>
  );
}

export function ChipLink({
  href,
  isActive = false,
  className,
  children,
}: {
  href: string;
  isActive?: boolean;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <Link
      href={href}
      aria-current={isActive ? 'page' : undefined}
      className={classesFor(isActive, className)}
    >
      {children}
    </Link>
  );
}
