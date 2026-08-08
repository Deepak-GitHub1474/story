'use client';

import { useState, useTransition } from 'react';
import { SharedStoryCard } from '@/components/SharedStoryCard';
import { Button } from '@/components/ui/Button';
import { cn } from '@/lib/cn';
import { SITE_URL } from '@/lib/config';
import { reshareStory, shareStory } from '@/lib/actions/stories';
import type { TSharedStory, TStory } from '@/lib/types';

function quotedFrom(story: TStory): TSharedStory {
  return (
    story.shared ?? {
      story_id: story.story_id,
      title: story.title,
      excerpt: story.excerpt,
      slug: story.slug,
      author: story.author,
    }
  );
}

export function ShareControl({ story }: { story: TStory }) {
  const [isOpen, setIsOpen] = useState(false);
  const [isComposing, setIsComposing] = useState(false);
  const [note, setNote] = useState('');
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  function copyLink() {
    setIsOpen(false);
    startTransition(async () => {
      await navigator.clipboard.writeText(
        story.slug ? `${SITE_URL}/s/${story.slug}` : `${SITE_URL}/story/${story.story_id}`,
      );
      await shareStory(story.story_id);
      setNotice('Link copied.');
    });
  }

  function post() {
    startTransition(async () => {
      const result = await reshareStory(story.story_id, note);
      if (result.error) {
        setError(result.error);
        return;
      }
      setNote('');
      setIsComposing(false);
      setNotice('Added to your story.');
    });
  }

  return (
    <div className="relative inline-flex items-center gap-3">
      <button
        type="button"
        aria-label="Share"
        aria-expanded={isOpen}
        onClick={() => setIsOpen((current) => !current)}
        className={cn(
          'group inline-flex items-center transition-colors',
          isOpen ? 'text-text-primary' : 'text-text-muted hover:text-text-secondary',
        )}
      >
        <svg
          viewBox="0 0 24 24"
          aria-hidden="true"
          className="size-[var(--size-icon-md)] group-active:scale-90"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.8"
        >
          <path d="m22 2-7 20-4-9-9-4Z" />
        </svg>
      </button>

      {notice ? (
        <span role="status" className="text-[length:var(--text-caption)] text-text-muted">
          {notice}
        </span>
      ) : null}

      {isOpen ? (
        <div className="absolute bottom-full left-0 z-20 mb-2 w-60 origin-bottom-left rounded-[length:var(--radius-md)] border border-border bg-surface p-1.5 shadow-lg">
          <button
            type="button"
            onClick={() => {
              setIsOpen(false);
              setIsComposing(true);
            }}
            className="block w-full rounded-[length:var(--radius-sm)] px-3 py-2.5 text-left transition-colors hover:bg-surface-raised"
          >
            <span className="block text-[length:var(--text-label)] font-medium">
              Add to your story
            </span>
            <span className="mt-0.5 block text-[length:var(--text-caption)] text-text-muted">
              Post it with a note of your own
            </span>
          </button>
          <button
            type="button"
            onClick={copyLink}
            className="block w-full rounded-[length:var(--radius-sm)] px-3 py-2.5 text-left transition-colors hover:bg-surface-raised"
          >
            <span className="block text-[length:var(--text-label)] font-medium">
              Copy link
            </span>
            <span className="mt-0.5 block text-[length:var(--text-caption)] text-text-muted">
              Anyone with the link can read it
            </span>
          </button>
        </div>
      ) : null}

      {isComposing ? (
        <div className="absolute bottom-full left-0 z-20 mb-2 w-[min(30rem,80vw)] rounded-[length:var(--radius-md)] border border-border bg-surface p-4 shadow-lg">
          <textarea
            autoFocus
            rows={3}
            maxLength={600}
            value={note}
            onChange={(event) => setNote(event.target.value)}
            placeholder="Say something about this…"
            className="w-full resize-none bg-transparent leading-relaxed outline-none placeholder:text-text-muted"
          />
          <SharedStoryCard shared={quotedFrom(story)} isStatic />
          <p className="mt-3 text-[length:var(--text-caption)] leading-relaxed text-text-muted">
            Your note is posted as your own story. Theirs stays theirs, and editing
            yours never touches it.
          </p>
          {error ? (
            <p role="alert" className="mt-2 text-[length:var(--text-caption)] text-danger">
              {error}
            </p>
          ) : null}
          <div className="mt-4 flex justify-end gap-3">
            <Button
              type="button"
              variant="ghost"
              isFullWidth={false}
              onClick={() => setIsComposing(false)}
            >
              Cancel
            </Button>
            <Button type="button" isFullWidth={false} disabled={isPending} onClick={post}>
              Post
            </Button>
          </div>
        </div>
      ) : null}
    </div>
  );
}
