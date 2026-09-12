import Link from 'next/link';
import { cn } from '@/lib/cn';
import { Icon } from '@/components/ui/Icon';
import type { TIconName } from '@/lib/icons';

export function IconButton({
  name,
  label,
  href,
  tone = 'muted',
  className,
}: {
  name: TIconName;
  label: string;
  href: string;
  tone?: 'muted' | 'primary';
  className?: string;
}) {
  return (
    <Link
      href={href}
      aria-label={label}
      title={label}
      className={cn(
        'inline-grid size-11 shrink-0 place-items-center rounded-full',
        'transition-colors duration-[var(--motion-fast)]',
        tone === 'muted'
          ? 'text-text-muted hover:text-text-primary'
          : 'text-text-primary hover:text-text-secondary',
        className,
      )}
    >
      <Icon name={name} />
    </Link>
  );
}
