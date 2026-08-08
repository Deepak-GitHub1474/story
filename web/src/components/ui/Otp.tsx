'use client';

import { useState } from 'react';
import { cn } from '@/lib/cn';

export function Otp({
  name = 'otp',
  hasError = false,
  length = 6,
}: {
  name?: string;
  hasError?: boolean;
  length?: number;
}) {
  const [value, setValue] = useState('');

  return (
    <div className="relative">
      <div className="flex justify-between gap-2" aria-hidden="true">
        {Array.from({ length }, (_, index) => (
          <span
            key={index}
            className={cn(
              'flex h-14 flex-1 items-center justify-center rounded-[length:var(--radius-md)] border bg-surface',
              'text-[length:var(--text-title)] font-medium transition-colors',
              hasError
                ? 'border-danger'
                : index === value.length
                  ? 'border-accent'
                  : 'border-border',
            )}
          >
            {value[index] ?? ''}
          </span>
        ))}
      </div>
      <input
        name={name}
        inputMode="numeric"
        autoComplete="one-time-code"
        aria-label="Verification code"
        maxLength={length}
        value={value}
        onChange={(event) => setValue(event.target.value.replace(/\D/g, ''))}
        autoFocus
        className="absolute inset-0 h-full w-full cursor-default opacity-0"
      />
    </div>
  );
}
