'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';

export function SearchBox({ initialQuery }: { initialQuery: string }) {
  const router = useRouter();
  const [value, setValue] = useState(initialQuery);

  useEffect(() => {
    const trimmed = value.trim();
    if (trimmed === initialQuery) return;

    const timer = setTimeout(() => {
      router.replace(trimmed ? `/search?q=${encodeURIComponent(trimmed)}` : '/search');
    }, 320);

    return () => clearTimeout(timer);
  }, [value, initialQuery, router]);

  return (
    <input
      type="search"
      value={value}
      onChange={(event) => setValue(event.target.value)}
      placeholder="People, communities, stories"
      aria-label="Search"
      autoFocus
      className="h-[var(--size-control-height)] w-full rounded-[length:var(--radius-md)] border border-border bg-surface px-4 text-[length:var(--text-body)] outline-none placeholder:text-text-muted focus:border-accent"
    />
  );
}
