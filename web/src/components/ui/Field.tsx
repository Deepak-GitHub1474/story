'use client';

import { useId } from 'react';
import { cn } from '@/lib/cn';

type Props = Omit<React.InputHTMLAttributes<HTMLInputElement>, 'size'> & {
  label: string;
  error?: string | null;
  hint?: string | null;
  suffix?: React.ReactNode;
};

export function Field({ label, error, hint, suffix, className, ...rest }: Props) {
  const id = useId();
  const describedBy = error ? `${id}-error` : hint ? `${id}-hint` : undefined;

  return (
    <div className="flex flex-col gap-2">
      <label
        htmlFor={id}
        className="text-[length:var(--text-label)] font-medium text-text-secondary"
      >
        {label}
      </label>

      <div className="relative">
        <input
          {...rest}
          id={id}
          aria-invalid={Boolean(error)}
          aria-describedby={describedBy}
          className={cn(
            'h-[var(--size-control-height)] w-full rounded-[length:var(--radius-md)]',
            'border bg-surface px-4 text-[length:var(--text-body)] text-text-primary',
            'transition-colors duration-150 outline-none',
            'placeholder:text-text-muted',
            'focus:border-accent focus:ring-1 focus:ring-accent',
            error ? 'border-danger focus:border-danger focus:ring-danger' : 'border-border',
            Boolean(suffix) && 'pr-12',
            className,
          )}
        />
        {suffix ? (
          <span className="absolute inset-y-0 right-3 flex items-center">{suffix}</span>
        ) : null}
      </div>

      {error ? (
        <p id={`${id}-error`} className="text-[length:var(--text-caption)] text-danger">
          {error}
        </p>
      ) : hint ? (
        <p id={`${id}-hint`} className="text-[length:var(--text-caption)] text-text-muted">
          {hint}
        </p>
      ) : null}
    </div>
  );
}
