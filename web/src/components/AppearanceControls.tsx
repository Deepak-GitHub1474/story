'use client';

import { useEffect, useState } from 'react';
import { cn } from '@/lib/cn';

const THEMES = [
  ['system', 'System'],
  ['midnight', 'Midnight'],
  ['paper', 'Paper'],
] as const;

const SIZES = [
  ['normal', 'Normal'],
  ['large', 'Large'],
] as const;

function Choice<T extends string>({
  options,
  value,
  onChange,
  label,
}: {
  options: readonly (readonly [T, string])[];
  value: T;
  onChange: (next: T) => void;
  label: string;
}) {
  return (
    <div className="flex items-center justify-between gap-4 px-4 py-3.5">
      <span className="text-[length:var(--text-label)]">{label}</span>
      <div
        role="radiogroup"
        aria-label={label}
        className="flex gap-1 rounded-[length:var(--radius-pill)] bg-surface-raised p-1"
      >
        {options.map(([option, optionLabel]) => (
          <button
            key={option}
            type="button"
            role="radio"
            aria-checked={value === option}
            onClick={() => onChange(option)}
            className={cn(
              'rounded-[length:var(--radius-pill)] px-3.5 py-1.5 text-[length:var(--text-caption)] transition-colors',
              value === option
                ? 'bg-accent font-semibold text-accent-text'
                : 'text-text-secondary hover:text-text-primary',
            )}
          >
            {optionLabel}
          </button>
        ))}
      </div>
    </div>
  );
}

export function AppearanceControls() {
  const [theme, setTheme] = useState<'system' | 'midnight' | 'paper'>('system');
  const [size, setSize] = useState<'normal' | 'large'>('normal');

  useEffect(() => {
    const storedTheme = localStorage.getItem('story.theme');
    const storedSize = localStorage.getItem('story.reading');
    if (storedTheme === 'midnight' || storedTheme === 'paper') setTheme(storedTheme);
    if (storedSize === 'large') setSize(storedSize);
  }, []);

  useEffect(() => {
    const root = document.documentElement;
    if (theme === 'system') {
      root.removeAttribute('data-theme');
      localStorage.removeItem('story.theme');
    } else {
      root.setAttribute('data-theme', theme);
      localStorage.setItem('story.theme', theme);
    }
  }, [theme]);

  useEffect(() => {
    const root = document.documentElement;
    if (size === 'large') {
      root.setAttribute('data-reading', 'large');
      localStorage.setItem('story.reading', 'large');
    } else {
      root.removeAttribute('data-reading');
      localStorage.removeItem('story.reading');
    }
  }, [size]);

  return (
    <>
      <Choice options={THEMES} value={theme} onChange={setTheme} label="Theme" />
      <Choice options={SIZES} value={size} onChange={setSize} label="Reading size" />
    </>
  );
}
