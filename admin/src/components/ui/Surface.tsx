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
        'rounded-[length:var(--radius-lg)] border border-border bg-surface p-5 sm:p-6',
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
    <section className="flex flex-col gap-3">
      <h2 className="px-0.5 text-[length:var(--text-caption)] font-medium tracking-[var(--tracking-eyebrow)] text-text-muted uppercase">
        {title}
      </h2>
      <div className="divide-y divide-border overflow-hidden rounded-[length:var(--radius-lg)] border border-border bg-surface">
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
      {value ? (
        <span className="truncate text-[length:var(--text-label)] text-text-muted">
          {value}
        </span>
      ) : null}
      {trailing}
    </>
  );

  const shared =
    'flex w-full items-center gap-3 px-4 py-3.5 text-[length:var(--text-label)] transition-colors duration-[var(--motion-fast)] hover:bg-surface-raised sm:px-5';

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
  tone?: 'neutral' | 'accent' | 'success' | 'danger' | 'warning';
  children: React.ReactNode;
}) {
  const tones = {
    neutral: 'border-border text-text-muted',
    accent: 'border-accent/40 text-accent',
    success: 'border-success/40 text-success',
    danger: 'border-danger/40 text-danger',
    warning: 'border-warning/40 text-warning',
  } as const;

  return (
    <span
      className={cn(
        'inline-flex items-center rounded-[length:var(--radius-sm)] border px-1.5 py-0.5',
        'text-[length:var(--text-micro)] font-medium tracking-[0.09em] uppercase',
        tones[tone],
      )}
    >
      {children}
    </span>
  );
}

export function Eyebrow({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <p
      className={cn(
        'text-[length:var(--text-caption)] font-medium tracking-[var(--tracking-eyebrow)] text-text-muted uppercase',
        className,
      )}
    >
      {children}
    </p>
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

export function Stat({
  label,
  value,
  tone = 'neutral',
}: {
  label: string;
  value: number | string;
  tone?: 'neutral' | 'danger' | 'warning';
}) {
  const tones = {
    neutral: 'text-text-primary',
    danger: 'text-danger',
    warning: 'text-warning',
  } as const;

  return (
    <div className="rounded-[length:var(--radius-lg)] border border-border bg-surface px-4 py-3">
      <dd className={cn('text-[length:var(--text-heading)] leading-none font-semibold', tones[tone])}>
        {value}
      </dd>
      <dt className="mt-2 text-[length:var(--text-caption)] tracking-[var(--tracking-eyebrow)] text-text-muted uppercase">
        {label}
      </dt>
    </div>
  );
}
