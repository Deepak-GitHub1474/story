import { cn } from '@/lib/cn';

export function Card({
  className,
  children,
  ...rest
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      {...rest}
      className={cn(
        'rounded-[length:var(--radius-md)] border border-border bg-surface p-6',
        className,
      )}
    >
      {children}
    </div>
  );
}

export function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="flex flex-col gap-2">
      <h2 className="px-1 text-[length:var(--text-caption)] font-semibold tracking-[0.12em] text-text-muted uppercase">
        {title}
      </h2>
      <div className="divide-y divide-border overflow-hidden rounded-[length:var(--radius-md)] border border-border bg-surface">
        {children}
      </div>
    </section>
  );
}

export function Row({
  label,
  value,
  trailing,
  href,
  onClick,
  isDanger = false,
}: {
  label: string;
  value?: string | null;
  trailing?: React.ReactNode;
  href?: string;
  onClick?: () => void;
  isDanger?: boolean;
}) {
  const inner = (
    <>
      <span className={cn('flex-1 text-left', isDanger && 'text-danger')}>{label}</span>
      {value ? <span className="text-text-muted">{value}</span> : null}
      {trailing}
    </>
  );

  const shared =
    'flex w-full items-center gap-3 px-4 py-4 text-[length:var(--text-body)] transition-colors hover:bg-surface-raised';

  if (href) {
    return (
      <a href={href} className={shared}>
        {inner}
      </a>
    );
  }

  if (onClick) {
    return (
      <button type="button" onClick={onClick} className={shared}>
        {inner}
      </button>
    );
  }

  return <div className={shared}>{inner}</div>;
}

export function Badge({
  tone = 'neutral',
  children,
}: {
  tone?: 'neutral' | 'accent' | 'success' | 'danger';
  children: React.ReactNode;
}) {
  const tones = {
    neutral: 'border-border text-text-secondary',
    accent: 'border-accent/50 text-accent',
    success: 'border-success/50 text-success',
    danger: 'border-danger/50 text-danger',
  } as const;

  return (
    <span
      className={cn(
        'inline-flex items-center rounded-[length:var(--radius-pill)] border px-2 py-0.5',
        'text-[length:var(--text-caption)] font-semibold',
        tones[tone],
      )}
    >
      {children}
    </span>
  );
}

export function Skeleton({ className }: { className?: string }) {
  return (
    <div
      className={cn(
        'animate-pulse rounded-[length:var(--radius-sm)] bg-surface-raised',
        className,
      )}
    />
  );
}
