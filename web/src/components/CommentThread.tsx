'use client';

import { useState, useTransition } from 'react';
import { Avatar } from '@/components/Avatar';
import { Button } from '@/components/ui/Button';
import { cn } from '@/lib/cn';
import { addComment, deleteComment, reportTarget } from '@/lib/actions/stories';
import { relativeTime } from '@/lib/format';
import type { TComment } from '@/lib/types';

const QUICK_EMOJI = ['❤️', '🫂', '😢', '🙏', '💛', '✨'];
const TAG_PATTERN = /(@[a-z0-9_]{3,20})/g;

function renderBody(body: string) {
  return body.split(TAG_PATTERN).map((part, index) =>
    part.startsWith('@') ? (
      <span key={index} className="font-semibold text-accent">
        {part}
      </span>
    ) : (
      part
    ),
  );
}

export function CommentThread({
  storyId,
  comments,
  currentUserId,
  isStoryAuthor,
}: {
  storyId: string;
  comments: TComment[];
  currentUserId: string;
  isStoryAuthor: boolean;
}) {
  const [body, setBody] = useState('');
  const [replyTo, setReplyTo] = useState<TComment | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  function submit() {
    const text = body.trim();
    if (!text) return;

    startTransition(async () => {
      const result = await addComment(
        storyId,
        text,
        replyTo?.parent_id ?? replyTo?.comment_id ?? null,
      );
      if (result.error) {
        setError(result.error);
        return;
      }
      setBody('');
      setReplyTo(null);
      setError(null);
    });
  }

  function startReply(comment: TComment) {
    setReplyTo(comment);
    const handle = comment.author.username;
    if (handle && !body.includes(`@${handle}`)) {
      setBody((current) => `@${handle} ${current}`.trimStart());
    }
  }

  return (
    <section className="mt-10">
      <h2 className="text-[length:var(--text-heading)] font-semibold">Comments</h2>

      {comments.length === 0 ? (
        <p className="mt-4 leading-relaxed text-text-muted">
          No comments yet. Say something that is not advice.
        </p>
      ) : (
        <ul className="mt-6 space-y-6">
          {comments.map((comment) => (
            <CommentItem
              key={comment.comment_id}
              comment={comment}
              storyId={storyId}
              currentUserId={currentUserId}
              isStoryAuthor={isStoryAuthor}
              onReply={startReply}
            />
          ))}
        </ul>
      )}

      <div className="sticky bottom-0 mt-8 border-t border-border bg-bg pt-4 pb-6">
        {replyTo ? (
          <div className="mb-3 flex items-center gap-2 rounded-[length:var(--radius-sm)] bg-surface-raised px-3 py-2 text-[length:var(--text-caption)] text-text-secondary">
            <span className="flex-1">Replying to {replyTo.author.display_name}</span>
            <button
              type="button"
              onClick={() => setReplyTo(null)}
              className="text-text-muted hover:text-text-primary"
            >
              Cancel
            </button>
          </div>
        ) : null}

        <div className="mb-3 flex gap-2 overflow-x-auto">
          {QUICK_EMOJI.map((emoji) => (
            <button
              key={emoji}
              type="button"
              onClick={() => setBody((current) => current + emoji)}
              className="rounded-[length:var(--radius-pill)] bg-surface-raised px-3 py-1 text-lg transition-transform hover:scale-110"
            >
              {emoji}
            </button>
          ))}
        </div>

        <div className="flex items-end gap-3">
          <textarea
            value={body}
            onChange={(event) => setBody(event.target.value)}
            rows={1}
            maxLength={2000}
            placeholder="Say something kind"
            className="max-h-40 min-h-[52px] flex-1 resize-y rounded-[length:var(--radius-md)] border border-border bg-surface px-4 py-3.5 text-[length:var(--text-body)] outline-none placeholder:text-text-muted focus:border-accent"
          />
          <Button
            type="button"
            onClick={submit}
            isLoading={isPending}
            disabled={!body.trim()}
            isFullWidth={false}
          >
            Send
          </Button>
        </div>

        {error ? (
          <p className="mt-2 text-[length:var(--text-caption)] text-danger">{error}</p>
        ) : null}
      </div>
    </section>
  );
}

function CommentItem({
  comment,
  storyId,
  currentUserId,
  isStoryAuthor,
  onReply,
  isReply = false,
}: {
  comment: TComment;
  storyId: string;
  currentUserId: string;
  isStoryAuthor: boolean;
  onReply: (comment: TComment) => void;
  isReply?: boolean;
}) {
  const [, startTransition] = useTransition();
  const canDelete = comment.author.user_id === currentUserId || isStoryAuthor;

  return (
    <li className={cn(isReply && 'ml-8')}>
      <div className="flex gap-3">
        <Avatar seed={comment.author.avatar_seed} size={isReply ? 24 : 30} />
        <div className="min-w-0 flex-1">
          <p className="leading-relaxed text-text-secondary">
            <span className="font-semibold text-text-primary">
              {comment.author.display_name}
            </span>{' '}
            {renderBody(comment.body)}
          </p>
          <div className="mt-1 flex flex-wrap gap-4 text-[length:var(--text-caption)] text-text-muted">
            <span>{relativeTime(comment.created_at)}</span>
            {comment.counts.likes > 0 ? (
              <span className="font-semibold">{comment.counts.likes} likes</span>
            ) : null}
            <button
              type="button"
              onClick={() => onReply(comment)}
              className="font-semibold hover:text-text-secondary"
            >
              Reply
            </button>
            <button
              type="button"
              onClick={() =>
                startTransition(async () => {
                  if (canDelete) {
                    await deleteComment(comment.comment_id, storyId);
                  } else {
                    await reportTarget('comment', comment.comment_id, 'harassment');
                  }
                })
              }
              className="hover:text-text-secondary"
            >
              {canDelete ? 'Delete' : 'Report'}
            </button>
          </div>
        </div>
      </div>

      {comment.replies && comment.replies.length > 0 ? (
        <ul className="mt-4 space-y-4">
          {comment.replies.map((reply) => (
            <CommentItem
              key={reply.comment_id}
              comment={reply}
              storyId={storyId}
              currentUserId={currentUserId}
              isStoryAuthor={isStoryAuthor}
              onReply={onReply}
              isReply
            />
          ))}
        </ul>
      ) : null}
    </li>
  );
}
