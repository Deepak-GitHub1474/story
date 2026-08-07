export type TChatPeer = {
  user_id: string;
  username: string;
  display_name: string;
  avatar_seed: string;
};

export type TConversation = {
  conversation_id: string;
  state: string;
  is_requester: boolean;
  other: TChatPeer;
  wrapped_cek: string | null;
  sender_public_key: string | null;
  unread_count: number;
  other_online: boolean | null;
  other_typing: boolean;
  their_last_read_message_id: string | null;
  last_message_at: string | null;
};

export type TChatMessage = {
  message_id: string;
  conversation_id: string;
  sender_id: string;
  ciphertext: string | null;
  reply_to: string | null;
  is_deleted: boolean;
  reactions: { user_id: string; emoji: string }[];
  created_at: string;
  text?: string;
};
