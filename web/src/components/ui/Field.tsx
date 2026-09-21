'use client';

import { useId, useState } from 'react';
import { cn } from '@/lib/cn';
import { Icon } from '@/components/ui/Icon';

type Props = Omit<React.InputHTMLAttributes<HTMLInputElement>, 'size'> & {
  label: string;
  error?: string | null;
  hint?: string | null;
  suffix?: React.ReactNode;
};

export function Field({ label, error, hint, suffix, className, ...rest }: Props) {
  const id = useId();
  const [isRevealed, setRevealed] = useState(false);
  const describedBy = error ? `${id}-error` : hint ? `${id}-hint` : undefined;
  const isPassword = rest.type === 'password';
  const trailing =
    suffix ??
    (isPassword ? (
      <button
        type="button"
        onClick={() => setRevealed((value) => !value)}
        aria-label={isRevealed ? 'Hide password' : 'Show password'}
        title={isRevealed ? 'Hide password' : 'Show password'}
        className="grid size-9 place-items-center text-text-muted outline-none transition-colors duration-[var(--motion-fast)] hover:text-text-primary"
      >
        <Icon name={isRevealed ? 'eyeOff' : 'eye'} size={20} />
      </button>
    ) : null);

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
          type={isPassword && isRevealed ? 'text' : rest.type}
          id={id}
          aria-invalid={Boolean(error)}
          aria-describedby={describedBy}
          className={cn(
            'h-[var(--size-control-height)] w-full rounded-[length:var(--radius-md)]',
            'border bg-surface px-3.5 text-[length:var(--text-body)] text-text-primary',
            'transition-colors duration-[var(--motion-fast)] outline-none',
            'placeholder:text-text-muted/70',
            'focus:border-accent focus:bg-bg',
            error
              ? 'border-danger focus:border-danger'
              : 'border-border hover:border-border-strong',
            Boolean(trailing) && 'pr-12',
            className,
          )}
        />
        {trailing ? (
          <span className="absolute inset-y-0 right-2 flex items-center text-text-muted">
            {trailing}
          </span>
        ) : null}
      </div>

      {error ? (
        <p id={`${id}-error`} className="text-[length:var(--text-caption)] text-danger">
          {error}
        </p>
      ) : hint ? (
        <p
          id={`${id}-hint`}
          className="text-[length:var(--text-caption)] leading-relaxed text-text-muted"
        >
          {hint}
        </p>
      ) : null}
    </div>
  );
}
