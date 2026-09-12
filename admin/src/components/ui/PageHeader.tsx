export function PageHeader({
  title,
  description,
  eyebrow,
  actions,
}: {
  title: string;
  description?: string;
  eyebrow?: string;
  actions?: React.ReactNode;
}) {
  return (
    <div className="mb-8 flex flex-wrap items-end justify-between gap-x-6 gap-y-4 sm:mb-10">
      <div className="min-w-0">
        {eyebrow ? (
          <p className="mb-3 text-[length:var(--text-caption)] font-medium tracking-[var(--tracking-eyebrow)] text-text-muted uppercase">
            {eyebrow}
          </p>
        ) : null}
        <h1 className="font-editorial text-[length:var(--text-title)] leading-[1.1] font-semibold tracking-[var(--tracking-title)] text-balance">
          {title}
        </h1>
        {description ? (
          <p className="mt-3 max-w-[58ch] leading-relaxed text-pretty text-text-secondary">
            {description}
          </p>
        ) : null}
      </div>
      {actions ? <div className="flex shrink-0 items-center gap-2">{actions}</div> : null}
    </div>
  );
}
