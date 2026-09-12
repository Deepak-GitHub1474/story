'use client';

import { useState, useTransition } from 'react';
import { Button } from '@/components/ui/Button';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';

export function AsyncButton({
  label,
  action,
  variant = 'secondary',
  confirmText,
  isFullWidth = true,
}: {
  label: string;
  action: () => Promise<{ error: string | null; ok: string | null } | void>;
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
  confirmText?: string;
  isFullWidth?: boolean;
}) {
  const [state, setState] = useState<{ error: string | null; ok: string | null }>({
    error: null,
    ok: null,
  });
  const [isPending, startTransition] = useTransition();
  const [isAsking, setAsking] = useState(false);

  function run() {
    startTransition(async () => {
      const result = await action();
      if (result) setState(result);
    });
  }

  return (
    <div className="flex flex-col gap-2">
      <Button
        type="button"
        variant={variant}
        isLoading={isPending}
        isFullWidth={isFullWidth}
        onClick={() => (confirmText ? setAsking(true) : run())}
      >
        {label}
      </Button>
      {state.error ? (
        <p role="alert" className="text-[length:var(--text-label)] text-danger">
          {state.error}
        </p>
      ) : null}
      {state.ok ? (
        <p role="status" className="text-[length:var(--text-label)] text-success">
          {state.ok}
        </p>
      ) : null}

      {confirmText ? (
        <ConfirmDialog
          isOpen={isAsking}
          title={label}
          body={confirmText}
          confirmLabel={label}
          isDanger={variant === 'danger'}
          isPending={isPending}
          onCancel={() => setAsking(false)}
          onConfirm={() => {
            setAsking(false);
            run();
          }}
        />
      ) : null}
    </div>
  );
}
