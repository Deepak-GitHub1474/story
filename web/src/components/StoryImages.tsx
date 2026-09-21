'use client';

import { useRef, useState } from 'react';
import { mediaUrl } from '@/lib/config';
import { PORTRAIT_BOUND } from '@/lib/imageShape';
import { cn } from '@/lib/cn';
import type { TImageFit } from '@/lib/types';

export function StoryImages({
  images,
  ratio,
  fit = 'cover',
}: {
  images: string[];
  ratio?: number | null;
  fit?: TImageFit;
}) {
  const track = useRef<HTMLDivElement>(null);
  const [page, setPage] = useState(0);

  if (images.length === 0) return null;

  const frame = ratio && ratio > 0 ? ratio : PORTRAIT_BOUND;

  return (
    <div className="mt-4">
      <div
        ref={track}
        onScroll={(event) => {
          const strip = event.currentTarget;
          const next = Math.round(strip.scrollLeft / Math.max(strip.clientWidth, 1));
          if (next !== page) setPage(next);
        }}
        className={cn(
          'relative flex snap-x snap-mandatory overflow-x-auto overscroll-x-contain',
          'rounded-[length:var(--radius-md)] border border-border bg-surface-raised',
          '[scrollbar-width:none] [&::-webkit-scrollbar]:hidden',
        )}
        style={{ aspectRatio: frame }}
      >
        {images.map((path, index) => (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            key={path}
            src={mediaUrl(path)}
            alt={images.length === 1 ? 'Picture in this story' : `Picture ${index + 1} of ${images.length}`}
            loading="lazy"
            decoding="async"
            className={cn(
              'h-full w-full shrink-0 snap-center snap-always',
              fit === 'contain' ? 'object-contain' : 'object-cover',
            )}
          />
        ))}

        {images.length > 1 ? (
          <span className="pointer-events-none sticky top-3 right-3 ml-auto h-fit shrink-0 rounded-[length:var(--radius-pill)] bg-black/55 px-2 py-0.5 text-[length:var(--text-caption)] font-medium text-white">
            {page + 1}/{images.length}
          </span>
        ) : null}
      </div>

      {images.length > 1 ? (
        <div className="mt-2 flex items-center justify-center gap-1.5">
          {images.map((path, index) => (
            <button
              key={path}
              type="button"
              aria-label={`Show picture ${index + 1}`}
              aria-current={index === page}
              onClick={() =>
                track.current?.scrollTo({
                  left: index * track.current.clientWidth,
                  behavior: 'smooth',
                })
              }
              className={cn(
                'rounded-full transition-all duration-150',
                index === page ? 'size-[7px] bg-accent' : 'size-[5px] bg-border',
              )}
            />
          ))}
        </div>
      ) : null}
    </div>
  );
}
