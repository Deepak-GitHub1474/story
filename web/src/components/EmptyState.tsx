export function EmptyState({
  title,
  body,
  action,
}: {
  title: string;
  body: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="mx-auto max-w-[38ch] py-20 text-center sm:py-28">
      <div aria-hidden="true" className="mx-auto h-px w-10 bg-border-strong" />
      <h2 className="font-editorial mt-8 text-[length:var(--text-heading)] leading-snug font-semibold tracking-[var(--tracking-title)] text-balance">
        {title}
      </h2>
      <p className="mt-3 leading-relaxed text-pretty text-text-secondary">{body}</p>
      {action ? <div className="mt-8 flex justify-center">{action}</div> : null}
    </div>
  );
}
