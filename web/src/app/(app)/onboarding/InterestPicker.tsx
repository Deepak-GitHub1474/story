'use client';

import { useRouter } from 'next/navigation';
import { useState, useTransition } from 'react';
import { Button } from '@/components/ui/Button';
import { cn } from '@/lib/cn';
import { updateInterests } from '@/lib/actions/account';

const MAX = 12;

type TInterest = { slug: string; name: string; category_id: string };

export function InterestPicker({ interests }: { interests: TInterest[] }) {
  const router = useRouter();
  const [selected, setSelected] = useState<string[]>([]);
  const [isPending, startTransition] = useTransition();

  const grouped = interests.reduce<Record<string, TInterest[]>>((acc, item) => {
    (acc[item.category_id] ??= []).push(item);
    return acc;
  }, {});

  function toggle(slug: string) {
    setSelected((current) =>
      current.includes(slug)
        ? current.filter((value) => value !== slug)
        : current.length < MAX
          ? [...current, slug]
          : current,
    );
  }

  return (
    <div className="mx-auto max-w-2xl">
      <h1 className="text-[length:var(--text-title)] font-semibold">
        What are you carrying?
      </h1>
      <p className="mt-2 max-w-prose leading-relaxed text-text-secondary">
        Pick up to {MAX}. This shapes what you are shown, and nobody else can see your
        choices.
      </p>

      <div className="mt-8 space-y-8">
        {Object.entries(grouped).map(([category, items]) => (
          <section key={category}>
            <h2 className="mb-3 text-[length:var(--text-caption)] font-semibold tracking-[0.12em] text-text-muted uppercase">
              {category.replace(/-/g, ' ')}
            </h2>
            <ul className="flex flex-wrap gap-2">
              {items.map((item) => {
                const isOn = selected.includes(item.slug);
                return (
                  <li key={item.slug}>
                    <button
                      type="button"
                      aria-pressed={isOn}
                      onClick={() => toggle(item.slug)}
                      className={cn(
                        'rounded-[length:var(--radius-pill)] border px-4 py-2',
                        'text-[length:var(--text-label)] transition-all duration-150',
                        isOn
                          ? 'scale-[1.03] border-accent bg-accent font-semibold text-accent-text'
                          : 'border-border text-text-secondary hover:border-text-muted',
                      )}
                    >
                      {item.name}
                    </button>
                  </li>
                );
              })}
            </ul>
          </section>
        ))}
      </div>

      <div className="sticky bottom-0 mt-10 flex gap-3 border-t border-border bg-bg py-5">
        <Button
          variant="ghost"
          isFullWidth={false}
          onClick={() => router.push('/feed')}
        >
          Skip
        </Button>
        <Button
          isLoading={isPending}
          onClick={() =>
            startTransition(async () => {
              if (selected.length) await updateInterests(selected);
              router.push('/feed');
            })
          }
        >
          {selected.length ? `Save ${selected.length} selected` : 'Continue'}
        </Button>
      </div>
    </div>
  );
}
