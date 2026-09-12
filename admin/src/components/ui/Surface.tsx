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
        'rounded-[length:var(--radius-lg)] border border-border bg-surface p-4 sm:p-5',
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
      <h2 className="text-[length:var(--text-micro)] font-medium tracking-[var(--tracking-eyebrow)] text-text-muted uppercase">
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
      {value ? <span className="text-text-muted">{value}</span> : null}
      {trailing}
    </>
  );

  const shared =
    'flex w-full items-center gap-3 px-4 py-3 text-[length:var(--text-label)] transition-colors duration-[var(--motion-fast)] hover:bg-surface-raised';

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
    success: 'border-success/45 text-success',
    danger: 'border-danger/45 text-danger',
    warning: 'border-warning/45 text-warning',
  } as const;

  return (
    <span
      className={cn(
        'inline-flex items-center rounded-[length:var(--radius-sm)] border px-1.5 py-0.5',
        'text-[length:var(--text-micro)] font-medium tracking-[0.08em] whitespace-nowrap uppercase',
        tones[tone],
      )}
    >
      {children}
    </span>
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
    <div className="rounded-[length:var(--radius-lg)] border border-border bg-surface px-3 py-2.5">
      <dd className={cn('numeric text-[1.375rem] leading-none font-semibold', tones[tone])}>
        {value}
      </dd>
      <dt className="mt-1.5 text-[length:var(--text-micro)] tracking-[0.07em] text-text-muted uppercase">
        {label}
      </dt>
    </div>
  );
}
