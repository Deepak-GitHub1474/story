class ChatBackup {
  const ChatBackup({
    required this.salt,
    required this.wrappedPrivateKey,
    required this.publicKey,
  });

  factory ChatBackup.fromJson(Map<String, dynamic> json) => ChatBackup(
    salt: json['salt'] as String,
    wrappedPrivateKey: json['wrapped_private_key'] as String,
    publicKey: json['public_key'] as String,
  );

  final String salt;
  final String wrappedPrivateKey;
  final String publicKey;
}

class PeerIdentity {
  const PeerIdentity({required this.publicKey, required this.userId});

  final String publicKey;
  final String userId;
}

class ChatPeer {
  const ChatPeer({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarSeed,
  });

  factory ChatPeer.fromJson(Map<String, dynamic> json) => ChatPeer(
    userId: json['user_id'] as String? ?? '',
    username: json['username'] as String? ?? '',
    displayName: json['display_name'] as String? ?? '',
    avatarSeed: json['avatar_seed'] as String? ?? '',
  );

  String get handle => username.isNotEmpty ? username : displayName;

  final String userId;
  final String username;
  final String displayName;
  final String avatarSeed;
}

class Conversation {
  const Conversation({
    required this.conversationId,
    required this.state,
    required this.isRequester,
    required this.other,
    required this.unreadCount,
    this.wrappedCek,
    this.senderPublicKey,
    this.theirLastReadMessageId,
    this.lastMessageAt,
    this.otherOnline,
    this.otherTyping = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    conversationId: json['conversation_id'] as String,
    state: json['state'] as String? ?? 'accepted',
    isRequester: json['is_requester'] as bool? ?? false,
    other: ChatPeer.fromJson(Map<String, dynamic>.from(json['other'] as Map? ?? {})),
    unreadCount: json['unread_count'] as int? ?? 0,
    wrappedCek: json['wrapped_cek'] as String?,
    senderPublicKey: json['sender_public_key'] as String?,
    theirLastReadMessageId: json['their_last_read_message_id'] as String?,
    lastMessageAt: json['last_message_at'] as String?,
    otherOnline: json['other_online'] as bool?,
    otherTyping: json['other_typing'] as bool? ?? false,
  );

  final String conversationId;
  final String state;
  final bool isRequester;
  final ChatPeer other;
  final int unreadCount;
  final String? wrappedCek;
  final String? senderPublicKey;
  final String? theirLastReadMessageId;
  final String? lastMessageAt;
  final bool? otherOnline;
  final bool otherTyping;

  bool get isPending => state == 'pending';
}

class ChatReaction {
  const ChatReaction({required this.userId, required this.emoji});

  factory ChatReaction.fromJson(Map<String, dynamic> json) =>
      ChatReaction(userId: json['user_id'] as String, emoji: json['emoji'] as String);

  final String userId;
  final String emoji;
}

class ChatMessage {
  const ChatMessage({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.isDeleted,
    required this.createdAt,
    required this.reactions,
    this.ciphertext,
    this.replyTo,
    this.text,
    this.isSending = false,
    this.hasFailed = false,
    this.editedAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    messageId: json['message_id'] as String,
    conversationId: json['conversation_id'] as String,
    senderId: json['sender_id'] as String,
    ciphertext: json['ciphertext'] as String?,
    replyTo: json['reply_to'] as String?,
    isDeleted: json['is_deleted'] as bool? ?? false,
    createdAt: json['created_at'] as String? ?? '',
    editedAt: json['edited_at'] as String?,
    reactions: (json['reactions'] as List<dynamic>? ?? [])
        .map((item) => ChatReaction.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
  );

  final String messageId;
  final String conversationId;
  final String senderId;
  final String? ciphertext;
  final String? replyTo;
  final bool isDeleted;
  final String createdAt;
  final List<ChatReaction> reactions;
  final String? text;
  final bool isSending;
  final bool hasFailed;
  final String? editedAt;

  ChatMessage withText(String? value) => ChatMessage(
    editedAt: editedAt,
    messageId: messageId,
    conversationId: conversationId,
    senderId: senderId,
    ciphertext: ciphertext,
    replyTo: replyTo,
    isDeleted: isDeleted,
    createdAt: createdAt,
    reactions: reactions,
    text: value,
    isSending: isSending,
    hasFailed: hasFailed,
  );

  ChatMessage asPending({bool failed = false}) => ChatMessage(
    editedAt: editedAt,
    messageId: messageId,
    conversationId: conversationId,
    senderId: senderId,
    ciphertext: ciphertext,
    replyTo: replyTo,
    isDeleted: isDeleted,
    createdAt: createdAt,
    reactions: reactions,
    text: text,
    isSending: !failed,
    hasFailed: failed,
  );
}

class ChatUnread {
  const ChatUnread({required this.unread, required this.requests});

  factory ChatUnread.fromJson(Map<String, dynamic> json) => ChatUnread(
    unread: json['unread'] as int? ?? 0,
    requests: json['requests'] as int? ?? 0,
  );

  final int unread;
  final int requests;

  int get total => unread + requests;
}

class ChatPerson {
  const ChatPerson({
    required this.userId,
    required this.displayName,
    required this.opensStraightAway,
    this.username,
    this.avatarSeed = '',
  });

  factory ChatPerson.fromJson(Map<String, dynamic> json) => ChatPerson(
    userId: json['user_id'] as String,
    displayName: json['display_name'] as String? ?? 'Someone',
    opensStraightAway: json['opens_straight_away'] as bool? ?? false,
    username: json['username'] as String?,
    avatarSeed: json['avatar_seed'] as String? ?? '',
  );

  final String userId;
  final String displayName;
  final bool opensStraightAway;
  final String? username;
  final String avatarSeed;

  String get handle => username ?? displayName;
}
