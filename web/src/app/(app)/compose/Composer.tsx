'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState, useTransition } from 'react';
import { Button } from '@/components/ui/Button';
import { createDraft, publishStory, saveStory } from '@/lib/actions/stories';
import type { TCommunity, TStory } from '@/lib/types';

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
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (!story || (title === (story.title ?? '') && body === (story.body ?? ''))) return;

    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(async () => {
      const result = await saveStory(story.story_id, title, body);
      setSaved(result.error ? '' : 'Draft saved');
      if (result.error) setError(result.error);
    }, AUTOSAVE_MS);

    return () => {
      if (timer.current) clearTimeout(timer.current);
    };
  }, [title, body, story]);

  const words = body.trim() ? body.trim().split(/\s+/).length : 0;
  const canPublish = body.trim().length >= MIN_PUBLISH_LENGTH;

  function publish(visibility: string, scheduledFor: string | null = null) {
    if (!story) return;
    startPublish(async () => {
      await saveStory(story.story_id, title, body);
      const result = await publishStory(
        story.story_id,
        visibility,
        community || null,
        scheduledFor,
      );
      if (result?.error) setError(result.error);
    });
  }

  if (!story) {
    return (
      <form action={createDraft} className="mx-auto max-w-2xl">
        <input
          name="title"
          value={title}
          onChange={(event) => setTitle(event.target.value)}
          maxLength={120}
          placeholder="Title, if you want one"
          className="w-full border-b border-border bg-transparent pb-4 text-[length:var(--text-title)] font-bold outline-none placeholder:text-text-muted focus:border-accent"
        />
        <textarea
          name="body"
          value={body}
          onChange={(event) => setBody(event.target.value)}
          rows={16}
          maxLength={20000}
          placeholder="Say it here. Nobody knows who you are."
          className="mt-6 w-full resize-y bg-transparent text-[1.0625rem] leading-[1.75] outline-none placeholder:text-text-muted"
        />
        <div className="mt-6 flex items-center justify-between">
          <span className="text-[length:var(--text-caption)] text-text-muted">
            {words} words
          </span>
          <Button type="submit" isFullWidth={false} disabled={!canPublish}>
            Continue
          </Button>
        </div>
      </form>
    );
  }

  return (
    <div className="mx-auto max-w-2xl">
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
          <h2 className="font-semibold">Who can read this?</h2>

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
            <Button
              size="sm"
              variant="secondary"
              onClick={() => {
                const when = prompt('Publish at (YYYY-MM-DD HH:MM)');
                if (!when) return;
                const parsed = new Date(when.replace(' ', 'T'));
                if (Number.isNaN(parsed.getTime())) {
                  setError('That is not a valid date and time.');
                  return;
                }
                publish('scheduled', parsed.toISOString());
              }}
            >
              Schedule
            </Button>
          </div>
        </div>
      ) : null}

      <input
        value={title}
        onChange={(event) => setTitle(event.target.value)}
        maxLength={120}
        placeholder="Title, if you want one"
        className="mt-8 w-full border-b border-border bg-transparent pb-4 text-[length:var(--text-title)] font-bold outline-none placeholder:text-text-muted focus:border-accent"
      />

      <textarea
        value={body}
        onChange={(event) => setBody(event.target.value)}
        rows={18}
        maxLength={20000}
        placeholder="Say it here. Nobody knows who you are."
        className="mt-6 w-full resize-y bg-transparent text-[1.0625rem] leading-[1.75] outline-none placeholder:text-text-muted"
      />

      <div className="mt-6 flex items-center justify-between border-t border-border pt-4">
        <span className="text-[length:var(--text-caption)] text-text-muted">
          {words} words
        </span>
        {error ? (
          <span className="text-[length:var(--text-caption)] text-danger">{error}</span>
        ) : null}
      </div>
    </div>
  );
}
