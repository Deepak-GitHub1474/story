'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';

export function UserLookup() {
  const router = useRouter();
  const [username, setUsername] = useState('');

  return (
    <form
      onSubmit={(event) => {
        event.preventDefault();
        const value = username.trim().toLowerCase();
        if (value) router.push(`/users/${encodeURIComponent(value)}`);
      }}
      className="flex flex-col gap-4"
    >
      <Field
        label="Username"
        value={username}
        onChange={(event) => setUsername(event.target.value)}
        placeholder="quiet_fox"
        autoCapitalize="none"
        spellCheck={false}
      />
      <Button type="submit" disabled={!username.trim()}>
        Look up
      </Button>
    </form>
  );
}
