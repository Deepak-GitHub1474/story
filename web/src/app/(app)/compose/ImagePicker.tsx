'use client';

import { useRef, useState } from 'react';
import { mediaUrl } from '@/lib/config';
import { isCropped, postRatioFor } from '@/lib/imageShape';
import { cn } from '@/lib/cn';
import { Icon } from '@/components/ui/Icon';
import type { TImageFit } from '@/lib/types';

const MAX_IMAGES = 8;
const MAX_BYTES = 8 * 1024 * 1024;
const KINDS = ['image/jpeg', 'image/png'];

function toBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(new Error('unreadable'));
    reader.onload = () => {
      const url = String(reader.result);
      resolve(url.slice(url.indexOf(',') + 1));
    };
    reader.readAsDataURL(file);
  });
}

function measure(file: File): Promise<{ width: number; height: number }> {
  return new Promise((resolve) => {
    const url = URL.createObjectURL(file);
    const image = new Image();
    image.onload = () => {
      URL.revokeObjectURL(url);
      resolve({ width: image.naturalWidth, height: image.naturalHeight });
    };
    image.onerror = () => {
      URL.revokeObjectURL(url);
      resolve({ width: 0, height: 0 });
    };
    image.src = url;
  });
}

export function ImagePicker({
  images,
  fit,
  canFit,
  variant = 'inline',
  onChange,
}: {
  images: string[];
  fit: TImageFit;
  canFit: boolean;
  variant?: 'inline' | 'icon' | 'preview';
  onChange: (next: {
    images: string[];
    ratio?: number | null;
    fit?: TImageFit;
    canFit?: boolean;
  }) => void;
}) {
  const input = useRef<HTMLInputElement>(null);
  const [isUploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function add(files: FileList | null) {
    if (!files || files.length === 0) return;

    setError(null);
    setUploading(true);

    const next = [...images];
    let shape: { ratio: number; canFit: boolean } | null = null;

    try {
      for (const file of Array.from(files).slice(0, MAX_IMAGES - images.length)) {
        if (!KINDS.includes(file.type)) {
          setError('Pictures can be JPEG or PNG.');
          continue;
        }
        if (file.size > MAX_BYTES) {
          setError('Pictures have to be under 8 MB.');
          continue;
        }

        const measured = next.length === 0 ? await measure(file) : null;

        const response = await fetch('/api/media', {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ kind: file.type, data: await toBase64(file) }),
        });
        const payload = (await response.json().catch(() => null)) as {
          url?: string;
          message?: string;
        } | null;

        if (!response.ok || !payload?.url) {
          setError(payload?.message ?? 'That picture would not upload.');
          continue;
        }

        if (measured) {
          shape = {
            ratio: postRatioFor(measured.width, measured.height),
            canFit: isCropped(measured.width, measured.height),
          };
        }
        next.push(payload.url);
      }

      if (next.length !== images.length) {
        onChange({
          images: next,
          ...(shape
            ? { ratio: shape.ratio, canFit: shape.canFit, fit: shape.canFit ? fit : 'cover' }
            : {}),
        });
      }
    } finally {
      setUploading(false);
      if (input.current) input.current.value = '';
    }
  }

  function remove(url: string) {
    const next = images.filter((item) => item !== url);
    onChange(
      next.length === 0
        ? { images: next, ratio: null, fit: 'cover', canFit: false }
        : { images: next },
    );
  }

  const field = (
    <input
      ref={input}
      type="file"
      accept="image/jpeg,image/png"
      multiple
      hidden
      onChange={(event) => void add(event.target.files)}
    />
  );

  if (variant === 'icon') {
    return (
      <>
        {field}
        <button
          type="button"
          onClick={() => input.current?.click()}
          disabled={isUploading || images.length >= MAX_IMAGES}
          aria-label={error ?? 'Add a picture'}
          title={error ?? 'Add a picture'}
          className="inline-grid size-11 place-items-center rounded-full text-text-primary transition-opacity duration-[var(--motion-fast)] disabled:opacity-40"
        >
          {isUploading ? (
            <span className="size-4.5 animate-spin rounded-full border-[1.5px] border-current border-t-transparent" />
          ) : (
            <Icon name="image" />
          )}
        </button>
      </>
    );
  }

  const gallery = (
    <>
      {images.length > 0 ? (
        <ul className="mt-4 flex flex-wrap gap-3">
          {images.map((url) => (
            <li key={url} className="relative">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={mediaUrl(url)}
                alt=""
                className={cn(
                  'size-20 rounded-[length:var(--radius-md)] border border-border',
                  fit === 'contain' ? 'object-contain' : 'object-cover',
                )}
              />
              <button
                type="button"
                onClick={() => remove(url)}
                aria-label="Remove this picture"
                className="absolute -top-2 -right-2 grid size-6 place-items-center rounded-full border border-border bg-bg text-text-secondary transition-colors hover:text-danger"
              >
                <Icon name="close" size={14} />
              </button>
            </li>
          ))}
        </ul>
      ) : null}
    </>
  );

  if (variant === 'preview') {
    return (
      <div>
        {canFit && images.length > 0 ? (
          <button
            type="button"
            onClick={() => onChange({ images, fit: fit === 'contain' ? 'cover' : 'contain' })}
            className="mt-4 inline-flex h-9 items-center rounded-[length:var(--radius-pill)] border border-border px-3.5 text-[length:var(--text-caption)] text-text-secondary"
          >
            {fit === 'contain' ? 'Showing all of it' : 'Filling the frame'}
          </button>
        ) : null}
        {gallery}
      </div>
    );
  }

  return (
    <div className="mt-6">
      <div className="flex flex-wrap items-center gap-3">
        {field}
        <button
          type="button"
          onClick={() => input.current?.click()}
          disabled={isUploading || images.length >= MAX_IMAGES}
          className="inline-flex h-9 items-center rounded-[length:var(--radius-md)] border border-border px-3.5 text-[length:var(--text-caption)] text-text-secondary transition-colors duration-[var(--motion-fast)] hover:border-border-strong hover:text-text-primary disabled:cursor-not-allowed disabled:opacity-45"
        >
          {isUploading
            ? 'Uploading…'
            : images.length === 0
              ? 'Add a picture'
              : `Add another (${images.length}/${MAX_IMAGES})`}
        </button>

        {canFit && images.length > 0 ? (
          <button
            type="button"
            onClick={() => onChange({ images, fit: fit === 'contain' ? 'cover' : 'contain' })}
            className="inline-flex h-9 items-center rounded-[length:var(--radius-md)] border border-border px-3.5 text-[length:var(--text-caption)] text-text-secondary transition-colors duration-[var(--motion-fast)] hover:border-border-strong hover:text-text-primary"
          >
            {fit === 'contain' ? 'Showing all of it' : 'Filling the frame'}
          </button>
        ) : null}
      </div>

      {error ? (
        <p role="alert" className="mt-3 text-[length:var(--text-caption)] text-danger">
          {error}
        </p>
      ) : null}

      {images.length > 0 ? (
        <ul className="mt-4 flex flex-wrap gap-3">
          {images.map((url) => (
            <li key={url} className="relative">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={mediaUrl(url)}
                alt=""
                className={cn(
                  'size-20 rounded-[length:var(--radius-md)] border border-border',
                  fit === 'contain' ? 'object-contain' : 'object-cover',
                )}
              />
              <button
                type="button"
                onClick={() => remove(url)}
                aria-label="Remove this picture"
                className="absolute -top-2 -right-2 grid size-6 place-items-center rounded-full border border-border bg-bg text-text-secondary transition-colors hover:text-danger"
              >
                ×
              </button>
            </li>
          ))}
        </ul>
      ) : (
        <p className="mt-3 text-[length:var(--text-caption)] text-text-muted">
          Hidden details like where a photo was taken are stripped before it is stored.
        </p>
      )}
    </div>
  );
}
