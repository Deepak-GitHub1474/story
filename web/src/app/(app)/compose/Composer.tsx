'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState, useTransition } from 'react';
import { Button } from '@/components/ui/Button';
import { createDraft, publishStory, saveStory } from '@/lib/actions/stories';
import { LANDSCAPE_BOUND, PORTRAIT_BOUND } from '@/lib/imageShape';
import type { TCommunity, TImageFit, TStory } from '@/lib/types';
import { ImagePicker } from './ImagePicker';
import { PolishSheet } from './PolishSheet';
import { WriteWithAI } from './WriteWithAI';

const AUTOSAVE_MS = 1200;
const MIN_PUBLISH_LENGTH = 20;

export function Composer({
  story,
  communities,
}: {
  story: TStory | null;
  communities: TCommunity[];
}) {
  const router = useRouter();
  const [title, setTitle] = useState(story?.title ?? '');
  const [body, setBody] = useState(story?.body ?? '');
  const [community, setCommunity] = useState(story?.community?.slug ?? '');
  const [saved, setSaved] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isPublishing, startPublish] = useTransition();
  const [showOptions, setShowOptions] = useState(false);
  const [scheduledFor, setScheduledFor] = useState('');
  const [images, setImages] = useState<string[]>(story?.images ?? []);
  const [ratio, setRatio] = useState<number | null>(story?.image_ratio ?? null);
  const [fit, setFit] = useState<TImageFit>(story?.image_fit ?? 'cover');
  const [canFit, setCanFit] = useState(
    story?.image_ratio === PORTRAIT_BOUND || story?.image_ratio === LANDSCAPE_BOUND,
  );
  const [sheet, setSheet] = useState<'write' | 'polish' | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const pictures = { images, image_ratio: ratio, image_fit: fit };

  const pictureKey = `${images.join('|')}|${ratio ?? ''}|${fit}`;

  useEffect(() => {
    if (!story) return;

    const untouched =
      title === (story.title ?? '') &&
      body === (story.body ?? '') &&
      pictureKey === `${(story.images ?? []).join('|')}|${story.image_ratio ?? ''}|${story.image_fit ?? 'cover'}`;
    if (untouched) return;

    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(async () => {
      const result = await saveStory(story.story_id, title, body, {
        images,
        image_ratio: ratio,
        image_fit: fit,
      });
      setSaved(result.error ? '' : 'Draft saved');
      if (result.error) setError(result.error);
    }, AUTOSAVE_MS);

    return () => {
      if (timer.current) clearTimeout(timer.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [title, body, story, pictureKey]);

  const words = body.trim() ? body.trim().split(/\s+/).length : 0;
  const canPublish = body.trim().length >= MIN_PUBLISH_LENGTH;

  function publish(visibility: string, scheduledFor: string | null = null) {
    if (!story) return;
    startPublish(async () => {
      await saveStory(story.story_id, title, body, pictures);
      const result = await publishStory(
        story.story_id,
        visibility,
        community || null,
        scheduledFor,
      );
      if (result?.error) setError(result.error);
    });
  }

  function onPictures(next: {
    images: string[];
    ratio?: number | null;
    fit?: TImageFit;
    canFit?: boolean;
  }) {
    setImages(next.images);
    if (next.ratio !== undefined) setRatio(next.ratio);
    if (next.fit !== undefined) setFit(next.fit);
    if (next.canFit !== undefined) setCanFit(next.canFit);
    setSaved('');
  }

  const aiControls = (
    <div className="mt-6 flex flex-wrap gap-2 border-t border-border pt-6">
      <button
        type="button"
        onClick={() => setSheet('write')}
        className="inline-flex h-9 items-center rounded-[length:var(--radius-md)] border border-border px-3.5 text-[length:var(--text-caption)] text-text-secondary transition-colors duration-[var(--motion-fast)] hover:border-border-strong hover:text-text-primary"
      >
        Write it with AI
      </button>
      <button
        type="button"
        onClick={() => setSheet('polish')}
        disabled={body.trim().length === 0}
        className="inline-flex h-9 items-center rounded-[length:var(--radius-md)] border border-border px-3.5 text-[length:var(--text-caption)] text-text-secondary transition-colors duration-[var(--motion-fast)] hover:border-border-strong hover:text-text-primary disabled:cursor-not-allowed disabled:opacity-45"
      >
        Another go at it
      </button>
    </div>
  );

  const sheets = (
    <>
      <WriteWithAI
        isOpen={sheet === 'write'}
        onClose={() => setSheet(null)}
        onWritten={(written) => {
          setTitle(written.title);
          setBody(written.body);
          setSaved('');
        }}
      />
      <PolishSheet
        isOpen={sheet === 'polish'}
        text={body}
        onClose={() => setSheet(null)}
        onKeep={(polished) => {
          setBody(polished);
          setSaved('');
        }}
      />
    </>
  );

  if (!story) {
    return (
      <form action={createDraft} className="max-w-2xl">
        <input
          name="title"
          value={title}
          onChange={(event) => setTitle(event.target.value)}
          maxLength={120}
          placeholder="Title, if you want one"
          className="w-full border-b border-border bg-transparent pb-4 font-editorial text-[length:var(--text-title)] font-semibold tracking-[var(--tracking-title)] outline-none placeholder:text-text-muted focus:border-accent"
        />
        <textarea
          name="body"
          value={body}
          onChange={(event) => setBody(event.target.value)}
          rows={7}
          maxLength={20000}
          placeholder="Say it here. Nobody knows who you are."
          className="mt-6 field-sizing-content min-h-[9lh] w-full resize-none bg-transparent text-[1.0625rem] leading-[1.75] outline-none placeholder:text-text-muted"
        />
        <input type="hidden" name="images" value={JSON.stringify(images)} />
        <input type="hidden" name="image_ratio" value={ratio ?? ''} />
        <input type="hidden" name="image_fit" value={fit} />

        <ImagePicker images={images} fit={fit} canFit={canFit} onChange={onPictures} />

        {aiControls}

        <div className="mt-6 flex items-center justify-between">
          <span className="text-[length:var(--text-caption)] text-text-muted">
            {words} words
          </span>
          <Button type="submit" isFullWidth={false} disabled={!canPublish}>
            Continue
          </Button>
        </div>

        {sheets}
      </form>
    );
  }

  return (
    <div className="max-w-2xl">
      <div className="flex items-center justify-between gap-4">
        <button
          type="button"
          onClick={() => router.back()}
          className="text-[length:var(--text-label)] text-text-muted hover:text-text-primary"
        >
          Close
        </button>
        <span className="text-[length:var(--text-caption)] text-text-muted">{saved}</span>
        <Button
          isFullWidth={false}
          size="sm"
          disabled={!canPublish}
          onClick={() => setShowOptions((value) => !value)}
        >
          Publish
        </Button>
      </div>

      {showOptions ? (
        <div className="mt-4 space-y-3 rounded-[length:var(--radius-md)] border border-border bg-surface p-5">
          <h2 className="font-medium">Who can read this?</h2>

          {communities.length > 0 ? (
            <label className="block">
              <span className="text-[length:var(--text-caption)] text-text-muted">
                Community
              </span>
              <select
                value={community}
                onChange={(event) => setCommunity(event.target.value)}
                className="mt-1 h-11 w-full rounded-[length:var(--radius-md)] border border-border bg-bg px-3 outline-none focus:border-accent"
              >
                <option value="">No community</option>
                {communities.map((item) => (
                  <option key={item.slug} value={item.slug}>
                    {item.name}
                  </option>
                ))}
              </select>
            </label>
          ) : null}

          <div className="grid gap-2 sm:grid-cols-3">
            <Button size="sm" onClick={() => publish('public')} isLoading={isPublishing}>
              Public
            </Button>
            <Button size="sm" variant="secondary" onClick={() => publish('private')}>
              Private
            </Button>
            <div className="flex flex-wrap items-center gap-2">
              <input
                type="datetime-local"
                value={scheduledFor}
                onChange={(event) => setScheduledFor(event.target.value)}
                aria-label="Publish at"
                className="h-[var(--size-control-height)] rounded-[length:var(--radius-md)] border border-border bg-surface px-3 text-[length:var(--text-label)] outline-none focus:border-accent"
              />
              <Button
                size="sm"
                variant="secondary"
                disabled={!scheduledFor}
                onClick={() => {
                  const parsed = new Date(scheduledFor);
                  if (Number.isNaN(parsed.getTime()) || parsed <= new Date()) {
                    setError('Pick a time in the future.');
                    return;
                  }
                  publish('scheduled', parsed.toISOString());
                }}
              >
                Schedule
              </Button>
            </div>
          </div>
        </div>
      ) : null}

      <input
        value={title}
        onChange={(event) => setTitle(event.target.value)}
        maxLength={120}
        placeholder="Title, if you want one"
        className="mt-8 w-full border-b border-border bg-transparent pb-4 font-editorial text-[length:var(--text-title)] font-semibold tracking-[var(--tracking-title)] outline-none placeholder:text-text-muted focus:border-accent"
      />

      <textarea
        value={body}
        onChange={(event) => setBody(event.target.value)}
        rows={9}
        maxLength={20000}
        placeholder="Say it here. Nobody knows who you are."
        className="mt-6 field-sizing-content min-h-[9lh] w-full resize-none bg-transparent text-[1.0625rem] leading-[1.75] outline-none placeholder:text-text-muted"
      />

      <ImagePicker images={images} fit={fit} canFit={canFit} onChange={onPictures} />

      {aiControls}

      <div className="mt-6 flex items-center justify-between border-t border-border pt-4">
        <span className="text-[length:var(--text-caption)] text-text-muted">
          {words} words
        </span>
        {error ? (
          <span className="text-[length:var(--text-caption)] text-danger">{error}</span>
        ) : null}
      </div>

      {sheets}
    </div>
  );
}
