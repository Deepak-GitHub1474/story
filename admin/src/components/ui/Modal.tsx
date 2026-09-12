'use client';

import { useEffect, useRef } from 'react';
import { cn } from '@/lib/cn';

type Size = 'sm' | 'md' | 'lg';

const SIZES: Record<Size, string> = {
  sm: 'w-[24rem]',
  md: 'w-[32rem]',
  lg: 'w-[44rem]',
};

export function Modal({
  title,
  description,
  isOpen,
  onClose,
  size = 'md',
  footer,
  children,
}: {
  title: string;
  description?: string;
  isOpen: boolean;
  onClose: () => void;
  size?: Size;
  footer?: React.ReactNode;
  children: React.ReactNode;
}) {
  const ref = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;

    if (isOpen && !dialog.open) dialog.showModal();
    if (!isOpen && dialog.open) dialog.close();
  }, [isOpen]);

  return (
    <dialog
      ref={ref}
      onClose={onClose}
      onClick={(event) => {
        if (event.target === ref.current) onClose();
      }}
      aria-label={title}
      className={cn(
        'm-auto flex max-h-[calc(100dvh-2rem)] max-w-[calc(100vw-2rem)] flex-col overflow-hidden',
        'rounded-[length:var(--radius-lg)] border border-border bg-bg p-0 text-text-primary',
        'backdrop:bg-black/65 backdrop:backdrop-blur-[2px]',
        '[&:not([open])]:hidden',
        SIZES[size],
      )}
    >
      <header className="flex shrink-0 items-start justify-between gap-4 border-b border-border px-5 py-4">
        <div className="min-w-0">
          <h2 className="font-editorial text-[length:var(--text-heading)] font-semibold tracking-[var(--tracking-title)]">
            {title}
          </h2>
          {description ? (
            <p className="mt-1 text-[length:var(--text-caption)] leading-relaxed text-text-muted">
              {description}
            </p>
          ) : null}
        </div>
        <button
          type="button"
          onClick={onClose}
          aria-label="Close"
          className="-mt-1 -mr-2 grid size-8 shrink-0 place-items-center rounded-[length:var(--radius-md)] text-text-muted transition-colors duration-[var(--motion-fast)] hover:bg-surface hover:text-text-primary"
        >
          <svg
            viewBox="0 0 24 24"
            aria-hidden="true"
            className="size-4"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinecap="round"
          >
            <path d="M6 6l12 12M18 6L6 18" />
          </svg>
        </button>
      </header>

      <div className="min-h-0 flex-1 overflow-y-auto px-5 py-5">{children}</div>

      {footer ? (
        <footer className="shrink-0 border-t border-border px-5 py-4">{footer}</footer>
      ) : null}
    </dialog>
  );
}
