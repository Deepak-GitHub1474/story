'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { backendFetch } from '../server/session';
import type { TComment, TStory } from '../types';

export async function createDraft(form: FormData): Promise<void> {
  const result = await backendFetch<{ story: TStory }>('/stories', {
    method: 'POST',
    body: {
      title: String(form.get('title') ?? '').trim() || null,
      body: String(form.get('body') ?? ''),
    },
  });
  if (!result.ok) redirect('/compose');
  redirect(`/compose?id=${result.value.story.story_id}`);
}

export async function reshareStory(storyId: string, note: string) {
  const created = await backendFetch<{ story: TStory }>('/stories', {
    method: 'POST',
    body: { title: null, body: note.trim(), shared_story_id: storyId },
  });
  if (!created.ok) return { error: created.message };

  const published = await backendFetch<{ story: TStory }>(
    `/stories/${created.value.story.story_id}/publish`,
    { method: 'POST', body: { visibility: 'public' } },
  );
  if (!published.ok) return { error: published.message };

  revalidatePath('/feed');
  revalidatePath('/profile');
  return { error: null };
}

export async function saveStory(storyId: string, title: string, body: string) {
  const result = await backendFetch<{ story: TStory }>(`/stories/${storyId}`, {
    method: 'PATCH',
    body: { title: title.trim(), body },
  });
  return result.ok ? { error: null } : { error: result.message };
}

export async function publishStory(
  storyId: string,
  visibility: string,
  communitySlug: string | null,
  scheduledFor: string | null,
) {
  const result = await backendFetch<{ story: TStory }>(
    `/stories/${storyId}/publish`,
    {
      method: 'POST',
      body: {
        visibility,
        ...(communitySlug ? { community_slug: communitySlug } : {}),
        ...(scheduledFor ? { scheduled_for: scheduledFor } : {}),
      },
    },
  );
  if (!result.ok) return { error: result.message };
  revalidatePath('/feed');
  redirect(`/story/${storyId}`);
}

export async function toggleLike(storyId: string, liked: boolean) {
  await backendFetch(`/stories/${storyId}/like`, {
    method: liked ? 'POST' : 'DELETE',
  });
  revalidatePath(`/story/${storyId}`);
}

export async function addComment(storyId: string, body: string, parentId: string | null) {
  const result = await backendFetch<{ comment: TComment }>(
    `/stories/${storyId}/comments`,
    { method: 'POST', body: { body, ...(parentId ? { parent_id: parentId } : {}) } },
  );
  revalidatePath(`/story/${storyId}`);
  return result.ok ? { error: null } : { error: result.message };
}

export async function deleteComment(commentId: string, storyId: string) {
  await backendFetch(`/comments/${commentId}`, { method: 'DELETE' });
  revalidatePath(`/story/${storyId}`);
}

export async function deleteStory(storyId: string) {
  await backendFetch(`/stories/${storyId}`, { method: 'DELETE' });
  revalidatePath('/feed');
  redirect('/profile');
}

export async function unpublishStory(storyId: string) {
  await backendFetch(`/stories/${storyId}/unpublish`, { method: 'POST' });
  revalidatePath('/feed');
  revalidatePath(`/story/${storyId}`);
}

export async function reportTarget(kind: string, id: string, reason: string) {
  const result = await backendFetch('/reports', {
    method: 'POST',
    body: { target_kind: kind, target_id: id, reason },
  });
  return result.ok ? { error: null } : { error: result.message };
}

export async function toggleFollow(username: string, follow: boolean) {
  await backendFetch(`/connections/${username}`, {
    method: follow ? 'POST' : 'DELETE',
  });
  revalidatePath(`/u/${username}`);
  revalidatePath('/feed');
}

export async function toggleMembership(slug: string, join: boolean) {
  await backendFetch(`/communities/${slug}/join`, {
    method: join ? 'POST' : 'DELETE',
  });
  revalidatePath('/communities');
  revalidatePath(`/communities/${slug}`);
}

export async function unblockUser(username: string) {
  await backendFetch(`/connections/${username}/block`, { method: 'DELETE' });
  revalidatePath('/people/blocked');
}

export async function blockUser(username: string) {
  await backendFetch(`/connections/${username}/block`, { method: 'POST' });
  revalidatePath('/feed');
}

export async function toggleCommentLike(
  commentId: string,
  storyId: string,
  liked: boolean,
) {
  await backendFetch(`/comments/${commentId}/like`, {
    method: liked ? 'POST' : 'DELETE',
  });
  revalidatePath(`/story/${storyId}`);
}

export async function loadReplies(commentId: string) {
  const result = await backendFetch<{ items: TComment[] }>(
    `/comments/${commentId}/replies`,
  );
  return result.ok ? result.value.items : [];
}

export async function shareStory(storyId: string) {
  await backendFetch(`/stories/${storyId}/share`, { method: 'POST' });
  revalidatePath(`/story/${storyId}`);
}

export async function editComment(commentId: string, storyId: string, body: string) {
  const result = await backendFetch(`/comments/${commentId}`, {
    method: 'PATCH',
    body: { body },
  });
  if (!result.ok) return { error: result.message };
  revalidatePath(`/story/${storyId}`);
  return { error: null };
}
