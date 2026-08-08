import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/result.dart';
import '../models/chat_models.dart';

class ChatRepository {
  const ChatRepository(this._client);

  final ApiClient _client;

  Future<Result<String>> publishIdentity(String publicKey) => _client.post(
    Endpoints.chatIdentity,
    body: {'public_key': publicKey},
    parse: (data) => data['public_key'] as String,
  );

  Future<Result<ChatBackup>> backup() =>
      _client.get(Endpoints.chatBackup, parse: ChatBackup.fromJson);

  Future<Result<bool>> storeBackup({
    required String salt,
    required String wrappedPrivateKey,
    required String publicKey,
    required Map<String, dynamic> kdf,
  }) => _client.post(
    Endpoints.chatBackup,
    body: {
      'salt': salt,
      'wrapped_private_key': wrappedPrivateKey,
      'public_key': publicKey,
      'kdf': kdf,
    },
    parse: (data) => data['stored'] as bool? ?? true,
  );

  Future<Result<PeerIdentity>> identityOf(String username) => _client.get(
    Endpoints.chatIdentityOf(username),
    parse: (data) => PeerIdentity(
      publicKey: data['public_key'] as String,
      userId: data['user_id'] as String,
    ),
  );

  Future<Result<bool>> heartbeat() =>
      _client.post(Endpoints.chatPresence, parse: (data) => data['online'] as bool? ?? true);

  Future<Result<bool>> typing(String conversationId) => _client.post(
    Endpoints.chatTyping(conversationId),
    parse: (data) => data['typing'] as bool? ?? true,
  );

  Future<Result<ChatUnread>> unread() =>
      _client.get(Endpoints.chatUnread, parse: ChatUnread.fromJson);

  Future<Result<Conversation>> start({
    required String username,
    required String wrappedForMe,
    required String wrappedForThem,
    required String senderPublicKey,
  }) => _client.post(
    Endpoints.chatConversations,
    body: {
      'username': username,
      'wrapped_cek_for_me': wrappedForMe,
      'wrapped_cek_for_them': wrappedForThem,
      'sender_public_key': senderPublicKey,
    },
    parse: (data) =>
        Conversation.fromJson(Map<String, dynamic>.from(data['conversation'] as Map)),
  );

  Future<Result<List<Conversation>>> conversations({String? state}) => _client.get(
    Endpoints.chatConversations,
    query: state == null ? null : {'state': state},
    parse: (data) => (data['items'] as List<dynamic>)
        .map((item) => Conversation.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
  );

  Future<Result<Conversation>> conversation(String id) => _client.get(
    Endpoints.chatConversation(id),
    parse: (data) =>
        Conversation.fromJson(Map<String, dynamic>.from(data['conversation'] as Map)),
  );

  Future<Result<bool>> rekey({
    required String conversationId,
    required String wrappedForMe,
    required String wrappedForThem,
    required String senderPublicKey,
  }) => _client.put(
    Endpoints.chatKeys(conversationId),
    body: {
      'wrapped_cek_for_me': wrappedForMe,
      'wrapped_cek_for_them': wrappedForThem,
      'sender_public_key': senderPublicKey,
    },
    parse: (data) => data['rekeyed'] as bool? ?? true,
  );

  Future<Result<List<ChatPerson>>> people({String? cursor, int limit = 20}) =>
      _client.get(
        Endpoints.chatPeople,
        query: {'limit': limit, 'cursor': ?cursor},
        parse: (data) => (data['items'] as List<dynamic>)
            .map((item) => ChatPerson.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
      );

  Future<Result<bool>> reject(String id) => _client.post(
    '${Endpoints.chatConversations}/$id/reject',
    parse: (data) => data['rejected'] as bool? ?? true,
  );

  Future<Result<bool>> accept(String id) => _client.post(
    Endpoints.chatAccept(id),
    parse: (data) => data['state'] == 'accepted',
  );

  Future<Result<bool>> removeConversation(String id) => _client.delete(
    Endpoints.chatConversation(id),
    parse: (data) => data['deleted'] as bool? ?? true,
  );

  Future<Result<ChatMessage>> send({
    required String conversationId,
    required String ciphertext,
    String? replyTo,
  }) => _client.post(
    Endpoints.chatMessages(conversationId),
    body: {'ciphertext': ciphertext, 'reply_to': ?replyTo},
    parse: (data) =>
        ChatMessage.fromJson(Map<String, dynamic>.from(data['message'] as Map)),
  );

  Future<Result<List<ChatMessage>>> messages(
    String conversationId, {
    String? cursor,
    String? after,
    int limit = 30,
  }) => _client.get(
    Endpoints.chatMessages(conversationId),
    query: {'limit': limit, 'cursor': ?cursor, 'after': ?after},
    parse: (data) => (data['items'] as List<dynamic>)
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
  );

  Future<Result<bool>> unsend(String conversationId, String messageId) => _client.delete(
    Endpoints.chatMessage(conversationId, messageId),
    parse: (data) => data['deleted'] as bool? ?? true,
  );

  Future<Result<bool>> react(
    String conversationId,
    String messageId,
    String emoji,
  ) => _client.post(
    Endpoints.chatReaction(conversationId, messageId),
    body: {'emoji': emoji},
    parse: (_) => true,
  );

  Future<Result<bool>> clearReaction(String conversationId, String messageId) =>
      _client.delete(
        Endpoints.chatReaction(conversationId, messageId),
        parse: (_) => true,
      );

  Future<Result<bool>> markRead(String conversationId, String messageId) => _client.post(
    Endpoints.chatRead(conversationId),
    body: {'message_id': messageId},
    parse: (_) => true,
  );

  Future<String?> realtimeTicket() async {
    final result = await _client.post<String>(
      Endpoints.realtimeTicket,
      parse: (data) => data['ticket'] as String,
    );
    return result.valueOrNull;
  }
}
