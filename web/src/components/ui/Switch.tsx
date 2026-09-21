'use client';

import { cn } from '@/lib/cn';

export function Switch({
  isOn,
  label,
  onToggle,
}: {
  isOn: boolean;
  label: string;
  onToggle: () => void;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={isOn}
      aria-label={label}
      onClick={onToggle}
      className={cn(
        'relative h-6 w-11 shrink-0 rounded-[length:var(--radius-pill)]',
        'transition-colors duration-[var(--motion-base)] ease-[var(--ease-out-quint)]',
        'focus-visible:ring-[1.5px] focus-visible:ring-accent focus-visible:ring-offset-2',
        'focus-visible:ring-offset-bg focus-visible:outline-none',
        isOn ? 'bg-accent-strong' : 'bg-surface-raised',
      )}
    >
      <span
        aria-hidden="true"
        className={cn(
          'absolute top-0.5 left-0.5 size-5 rounded-full',
          'transition-transform duration-[var(--motion-base)] ease-[var(--ease-out-quint)]',
          isOn ? 'translate-x-5 bg-accent-text' : 'translate-x-0 bg-text-muted',
        )}
      />
    </button>
  );
}
