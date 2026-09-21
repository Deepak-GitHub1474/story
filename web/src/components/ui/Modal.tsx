'use client';

import { useEffect, useRef } from 'react';
import { cn } from '@/lib/cn';
import { Icon } from '@/components/ui/Icon';

type Size = 'sm' | 'md' | 'lg';

const SIZES: Record<Size, string> = {
  sm: 'sm:w-[24rem]',
  md: 'sm:w-[32rem]',
  lg: 'sm:w-[44rem]',
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
      data-surface="app"
      className={cn(
        'flex flex-col overflow-hidden p-0 text-text-primary',
        'backdrop:bg-black/65 backdrop:backdrop-blur-[2px]',
        '[&:not([open])]:hidden',
        'm-0 mt-auto max-h-[88dvh] w-full max-w-none border-t border-border bg-surface',
        'rounded-t-[length:var(--radius-lg)] pb-[env(safe-area-inset-bottom)]',
        'animate-[sheet-up_var(--motion-base)_var(--ease-out-quint)] motion-reduce:animate-none',
        'sm:m-auto sm:max-h-[calc(100dvh-2rem)] sm:max-w-[calc(100vw-2rem)] sm:animate-none',
        'sm:rounded-[length:var(--radius-lg)] sm:border sm:bg-bg sm:pb-0',
        SIZES[size],
      )}
    >
      <span
        aria-hidden="true"
        className="mx-auto mt-2 mb-1 h-1 w-[38px] shrink-0 rounded-full bg-border sm:hidden"
      />
      <header className="flex shrink-0 items-start justify-between gap-4 border-b border-border px-4 py-2 sm:px-5 sm:py-4">
        <div className="min-w-0">
          <h2 className="text-[length:var(--text-heading)] font-medium sm:font-editorial sm:font-semibold sm:tracking-[var(--tracking-title)]">
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
          className="-mr-2 grid size-9 shrink-0 place-items-center text-text-muted outline-none transition-colors duration-[var(--motion-fast)] hover:text-text-primary"
        >
          <Icon name="close" size={20} />
        </button>
      </header>

      <div className="min-h-0 flex-1 overflow-y-auto px-4 py-4 sm:px-5 sm:py-5">{children}</div>

      {footer ? (
        <footer className="shrink-0 border-t border-border px-4 py-4 sm:px-5">{footer}</footer>
      ) : null}
    </dialog>
  );
}
