export function PageHeader({
  title,
  description,
  actions,
}: {
  title: string;
  description?: string;
  actions?: React.ReactNode;
}) {
  return (
    <div className="flex flex-wrap items-start justify-between gap-x-6 gap-y-3">
      <div className="min-w-0">
        <h1 className="text-[length:var(--text-title)] leading-tight font-semibold tracking-[var(--tracking-title)]">
          {title}
        </h1>
        {description ? (
          <p className="mt-1.5 max-w-[70ch] text-[length:var(--text-label)] leading-relaxed text-text-secondary">
            {description}
          </p>
        ) : null}
      </div>
      {actions ? <div className="flex shrink-0 items-center gap-2">{actions}</div> : null}
    </div>
  );
}
