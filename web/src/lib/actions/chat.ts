'use server';

import { revalidatePath } from 'next/cache';
import { backendFetch } from '../server/session';

export async function publishChatKey(publicKey: string) {
  await backendFetch('/chat/identity', {
    method: 'POST',
    body: { public_key: publicKey },
  });
}

export async function peerIdentity(username: string) {
  const result = await backendFetch<{ public_key: string; user_id: string }>(
    `/chat/identity/${username}`,
  );
  return result.ok ? result.value : null;
}

export async function startConversation(body: {
  username: string;
  wrapped_cek_for_me: string;
  wrapped_cek_for_them: string;
  sender_public_key: string;
}) {
  const result = await backendFetch<{ conversation: { conversation_id: string } }>(
    '/chat/conversations',
    { method: 'POST', body },
  );
  revalidatePath('/chats');
  return result.ok ? result.value.conversation.conversation_id : null;
}

export async function sendMessage(
  conversationId: string,
  ciphertext: string,
  replyTo?: string,
) {
  const result = await backendFetch(
    `/chat/conversations/${conversationId}/messages`,
    { method: 'POST', body: { ciphertext, reply_to: replyTo ?? null } },
  );
  revalidatePath(`/chats/${conversationId}`);
  return result.ok;
}

export async function acceptConversation(conversationId: string) {
  await backendFetch(`/chat/conversations/${conversationId}/accept`, {
    method: 'POST',
  });
  revalidatePath('/chats');
  revalidatePath(`/chats/${conversationId}`);
}

export async function markConversationRead(
  conversationId: string,
  messageId: string,
) {
  await backendFetch(`/chat/conversations/${conversationId}/read`, {
    method: 'POST',
    body: { message_id: messageId },
  });
}

export async function announceTyping(conversationId: string) {
  await backendFetch(`/chat/conversations/${conversationId}/typing`, {
    method: 'POST',
  });
}

export async function heartbeat() {
  await backendFetch('/chat/presence', { method: 'POST' });
}

export async function unsendMessage(conversationId: string, messageId: string) {
  await backendFetch(
    `/chat/conversations/${conversationId}/messages/${messageId}`,
    { method: 'DELETE' },
  );
  revalidatePath(`/chats/${conversationId}`);
}
