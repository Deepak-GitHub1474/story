'use client';

import { useOptimistic, useState, useTransition } from 'react';
import { Avatar } from '@/components/Avatar';
import { Button } from '@/components/ui/Button';
import { cn } from '@/lib/cn';
import { ReportMenu } from '@/components/ReportMenu';
import {
  addComment,
  deleteComment,
  loadReplies,
  toggleCommentLike,
} from '@/lib/actions/stories';
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
  const [isReporting, setIsReporting] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [extraReplies, setExtraReplies] = useState<TComment[] | null>(null);
  const [like, setLike] = useOptimistic(
    { isLiked: comment.is_liked, count: comment.counts.likes },
    (current, next: boolean) => ({
      isLiked: next,
      count: current.count + (next ? 1 : -1),
    }),
  );

  const canDelete = comment.author.user_id === currentUserId || isStoryAuthor;
  const shown = extraReplies ?? comment.replies ?? [];
  const hidden = comment.counts.replies - shown.length;

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
          <div className="mt-1 flex flex-wrap items-center gap-4 text-[length:var(--text-caption)] text-text-muted">
            <span>{relativeTime(comment.created_at)}</span>
            <button
              type="button"
              aria-pressed={like.isLiked}
              aria-label={like.isLiked ? 'Unlike comment' : 'Like comment'}
              onClick={() =>
                startTransition(async () => {
                  const next = !like.isLiked;
                  setLike(next);
                  await toggleCommentLike(comment.comment_id, storyId, next);
                })
              }
              className={cn(
                'inline-flex items-center gap-1 font-semibold transition-colors',
                like.isLiked ? 'text-danger' : 'hover:text-text-secondary',
              )}
            >
              <svg
                viewBox="0 0 24 24"
                aria-hidden="true"
                className="size-3.5"
                fill={like.isLiked ? 'currentColor' : 'none'}
                stroke="currentColor"
                strokeWidth="2"
              >
                <path d="M12 20.5 4.4 13a4.6 4.6 0 0 1 6.5-6.5l1.1 1.1 1.1-1.1A4.6 4.6 0 0 1 19.6 13Z" />
              </svg>
              {like.count > 0 ? like.count : ''}
            </button>
            <button
              type="button"
              onClick={() => onReply(comment)}
              className="font-semibold hover:text-text-secondary"
            >
              Reply
            </button>
            {canDelete ? (
              <button
                type="button"
                onClick={() =>
                  startTransition(async () => {
                    await deleteComment(comment.comment_id, storyId);
                  })
                }
                className="hover:text-text-secondary"
              >
                Delete
              </button>
            ) : (
              <button
                type="button"
                onClick={() => setIsReporting((value) => !value)}
                className="hover:text-text-secondary"
              >
                Report
              </button>
            )}
            {notice ? <span role="status">{notice}</span> : null}
          </div>

          {isReporting ? (
            <div className="mt-3 overflow-hidden rounded-[length:var(--radius-md)] border border-border bg-surface">
              <ReportMenu
                kind="comment"
                targetId={comment.comment_id}
                onDone={(message) => {
                  setIsReporting(false);
                  setNotice(message);
                }}
              />
            </div>
          ) : null}
        </div>
      </div>

      {shown.length > 0 ? (
        <ul className="mt-4 space-y-4">
          {shown.map((reply) => (
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

      {hidden > 0 ? (
        <button
          type="button"
          onClick={() =>
            startTransition(async () => {
              setExtraReplies(await loadReplies(comment.comment_id));
            })
          }
          className="mt-3 ml-8 text-[length:var(--text-caption)] font-semibold text-text-muted hover:text-text-secondary"
        >
          View {hidden} more {hidden === 1 ? 'reply' : 'replies'}
        </button>
      ) : null}
    </li>
  );
}
