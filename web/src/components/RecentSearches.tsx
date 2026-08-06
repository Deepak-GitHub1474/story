'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import {
  clearSearches,
  forgetSearch,
  recentSearches,
  rememberSearch,
} from '@/lib/recentSearches';

export function RecentSearches({ query }: { query: string }) {
  const router = useRouter();
  const [items, setItems] = useState<string[]>([]);

  useEffect(() => {
    setItems(query ? rememberSearch(query) : recentSearches());
  }, [query]);

  if (query || items.length === 0) return null;

  return (
    <section className="mt-10">
      <div className="flex items-center justify-between">
        <h2 className="text-[length:var(--text-caption)] font-semibold tracking-[0.12em] text-text-muted uppercase">
          Recent
        </h2>
        <button
          type="button"
          onClick={() => setItems(clearSearches())}
          className="text-[length:var(--text-caption)] font-semibold text-accent hover:underline"
        >
          Clear all
        </button>
      </div>

      <ul className="mt-3 divide-y divide-border border-y border-border">
        {items.map((term) => (
          <li key={term} className="flex items-center gap-3 py-3">
            <button
              type="button"
              onClick={() => router.push(`/search?q=${encodeURIComponent(term)}`)}
              className="flex-1 text-left text-text-primary"
            >
              {term}
            </button>
            <button
              type="button"
              aria-label={`Remove ${term}`}
              onClick={() => setItems(forgetSearch(term))}
              className="rounded-full p-1.5 text-text-muted transition-colors hover:bg-surface hover:text-text-primary"
            >
              <svg
                viewBox="0 0 24 24"
                aria-hidden="true"
                className="size-4"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
              >
                <path d="M18 6 6 18M6 6l12 12" />
              </svg>
            </button>
          </li>
        ))}
      </ul>
    </section>
  );
}
