'use client';

import { useActionState } from 'react';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { EMPTY, updateProfile } from '@/lib/actions/account';

export function EditProfileForm({
  displayName,
  bio,
}: {
  displayName: string;
  bio: string;
}) {
  const [state, action, isPending] = useActionState(updateProfile, EMPTY);

  return (
    <form action={action} className="mx-auto flex max-w-lg flex-col gap-6">
      <h1 className="text-[length:var(--text-title)] font-semibold">Edit profile</h1>

      <Field
        label="Display name"
        name="display_name"
        defaultValue={displayName}
        maxLength={40}
        required
        hint="Shown on your stories. Change it whenever you like."
      />

      <div className="flex flex-col gap-2">
        <label
          htmlFor="bio"
          className="text-[length:var(--text-label)] font-medium text-text-secondary"
        >
          Bio
        </label>
        <textarea
          id="bio"
          name="bio"
          defaultValue={bio}
          maxLength={200}
          rows={3}
          placeholder="Say as little as you want."
          className="resize-y rounded-[length:var(--radius-md)] border border-border bg-surface px-4 py-3 outline-none placeholder:text-text-muted focus:border-accent"
        />
        <p className="text-[length:var(--text-caption)] text-text-muted">
          Up to 200 characters. Links are not allowed — a link is an identity.
        </p>
      </div>

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
        Save
      </Button>
    </form>
  );
}
