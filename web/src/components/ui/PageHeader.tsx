import Link from 'next/link';
import { Icon } from '@/components/ui/Icon';

export function PageHeader({
  title,
  description,
  eyebrow,
  backHref,
  actions,
}: {
  title: string;
  description?: string;
  eyebrow?: string;
  backHref?: string;
  actions?: React.ReactNode;
}) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-x-6 gap-y-4 sm:mb-10">
      <div className="flex min-w-0 flex-1 items-start gap-2">
        {backHref ? (
          <Link
            href={backHref}
            aria-label="Back"
            className="-ml-2 inline-grid size-11 shrink-0 place-items-center rounded-full text-text-primary sm:hidden"
          >
            <Icon name="arrowLeft" />
          </Link>
        ) : null}

        <div className="min-w-0 flex-1">
          {eyebrow ? (
            <p className="mb-3 hidden text-[length:var(--text-caption)] font-medium tracking-[var(--tracking-eyebrow)] text-text-muted uppercase sm:block">
              {eyebrow}
            </p>
          ) : null}
          <h1 className="text-[length:var(--text-heading)] leading-[1.2] font-medium text-balance sm:font-editorial sm:text-[length:var(--text-title)] sm:leading-[1.1] sm:font-semibold sm:tracking-[var(--tracking-title)]">
            {title}
          </h1>
          {description ? (
            <p className="mt-2 max-w-[58ch] text-[length:var(--text-label)] leading-[1.5] text-pretty text-text-secondary sm:mt-3 sm:text-[length:var(--text-body)] sm:leading-relaxed">
              {description}
            </p>
          ) : null}
        </div>
      </div>
      {actions ? <div className="flex shrink-0 items-center gap-2">{actions}</div> : null}
    </div>
  );
}
