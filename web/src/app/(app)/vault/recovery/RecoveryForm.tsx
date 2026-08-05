'use client';

import { useActionState } from 'react';
import { Button } from '@/components/ui/Button';
import { EMPTY, openPasscodeRelease } from '@/lib/actions/recovery';

export function RecoveryForm() {
  const [state, action, isPending] = useActionState(openPasscodeRelease, EMPTY);

  return (
    <form action={action} className="flex flex-col gap-4">
      <label
        htmlFor="reason"
        className="text-[length:var(--text-label)] font-medium text-text-secondary"
      >
        Why do you need your passcode released?
      </label>
      <textarea
        id="reason"
        name="reason"
        rows={4}
        required
        minLength={10}
        placeholder="Say what happened, in your own words."
        className="resize-y rounded-[length:var(--radius-md)] border border-border bg-surface px-4 py-3 outline-none placeholder:text-text-muted focus:border-accent"
      />
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
      <Button type="submit" isLoading={isPending}>
        Ask for a passcode release
      </Button>
    </form>
  );
}
