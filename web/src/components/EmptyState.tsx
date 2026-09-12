import { Icon } from '@/components/ui/Icon';
import type { TIconName } from '@/lib/icons';

export function EmptyState({
  title,
  body,
  icon = 'story',
  action,
}: {
  title: string;
  body: string;
  icon?: TIconName;
  action?: React.ReactNode;
}) {
  return (
    <div className="mx-auto max-w-[38ch] px-6 py-12 text-center sm:py-20">
      <span className="inline-flex text-text-muted">
        <Icon name={icon} size={44} strokeWidth={1.4} />
      </span>
      <h2 className="mt-4 text-[length:var(--text-heading)] font-medium text-balance">{title}</h2>
      <p className="mt-2 text-[length:var(--text-body)] leading-[1.6] text-pretty text-text-secondary">
        {body}
      </p>
      {action ? <div className="mt-6 flex justify-center">{action}</div> : null}
    </div>
  );
}
