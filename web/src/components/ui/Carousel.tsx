'use client';

import { useEffect, useRef, useState } from 'react';
import { cn } from '@/lib/cn';

export function Carousel({
  label,
  as = 'ul',
  children,
}: {
  label: string;
  as?: 'ul' | 'div';
  children: React.ReactNode;
}) {
  const Track = as;
  const track = useRef<HTMLUListElement & HTMLDivElement>(null);
  const [atStart, setAtStart] = useState(true);
  const [atEnd, setAtEnd] = useState(true);

  function measure() {
    const strip = track.current;
    if (!strip) return;
    const max = strip.scrollWidth - strip.clientWidth;
    setAtStart(strip.scrollLeft <= 1);
    setAtEnd(strip.scrollLeft >= max - 1);
  }

  useEffect(() => {
    measure();
    const strip = track.current;
    if (!strip) return;
    const observer = new ResizeObserver(measure);
    observer.observe(strip);
    return () => observer.disconnect();
  }, []);

  function nudge(direction: -1 | 1) {
    const strip = track.current;
    if (!strip) return;
    strip.scrollBy({ left: direction * strip.clientWidth * 0.8, behavior: 'smooth' });
  }

  const hasOverflow = !(atStart && atEnd);

  return (
    <div className="relative">
      <Track
        ref={track}
        onScroll={measure}
        className="flex snap-x snap-mandatory gap-2 overflow-x-auto pb-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
      >
        {children}
      </Track>

      {hasOverflow ? (
        <>
          <Arrow
            side="left"
            label={`Previous ${label}`}
            isHidden={atStart}
            onClick={() => nudge(-1)}
          />
          <Arrow
            side="right"
            label={`More ${label}`}
            isHidden={atEnd}
            onClick={() => nudge(1)}
          />
        </>
      ) : null}
    </div>
  );
}

function Arrow({
  side,
  label,
  isHidden,
  onClick,
}: {
  side: 'left' | 'right';
  label: string;
  isHidden: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      tabIndex={isHidden ? -1 : 0}
      onClick={onClick}
      className={cn(
        'absolute top-1/2 z-10 grid size-9 -translate-y-1/2 place-items-center',
        'rounded-full border border-border bg-bg/90 text-text-secondary backdrop-blur-sm',
        'transition-[opacity,color,border-color] duration-[var(--motion-fast)]',
        'hover:border-border-strong hover:text-text-primary',
        side === 'left' ? '-left-4' : '-right-4',
        isHidden ? 'pointer-events-none opacity-0' : 'opacity-100',
      )}
    >
      <svg
        viewBox="0 0 24 24"
        aria-hidden="true"
        className="size-4"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d={side === 'left' ? 'M15 6l-6 6 6 6' : 'M9 6l6 6-6 6'} />
      </svg>
    </button>
  );
}
