import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/chat_crypto.dart';
import '../../../core/crypto/vault_crypto.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/chat_repository.dart';
import '../models/chat_models.dart';

final chatCryptoProvider = Provider<ChatCrypto>((ref) => const ChatCrypto());

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);

final chatIdentityProvider = FutureProvider<ChatIdentity?>((ref) async {
  final userId = ref.watch(authProvider).user?.userId;
  if (userId == null) return null;

  final store = ref.read(secureStoreProvider);
  final crypto = ref.read(chatCryptoProvider);
  final repository = ref.read(chatRepositoryProvider);

  final stored = await store.readChatKey(userId);
  if (stored != null) {
    final identity = await crypto.restoreIdentity(stored);
    await repository.publishIdentity(identity.publicKey);
    return identity;
  }

  final identity = await crypto.newIdentity();
  await store.saveChatKey(userId, identity.privateKey);
  await repository.publishIdentity(identity.publicKey);
  return identity;
});

final conversationsProvider =
    FutureProvider.family<List<Conversation>, String?>((ref, state) async {
      final result = await ref.watch(chatRepositoryProvider).conversations(state: state);
      return result.valueOrNull ?? const [];
    });

final chatUnreadProvider = FutureProvider<ChatUnread>((ref) async {
  final result = await ref.watch(chatRepositoryProvider).unread();
  return result.valueOrNull ?? const ChatUnread(unread: 0, requests: 0);
});

class ConversationState {
  const ConversationState({
    this.messages = const [],
    this.conversation,
    this.isLoading = true,
    this.isSending = false,
    this.hasMore = false,
    this.cursor,
    this.error,
    this.needsRekey = false,
  });

  final List<ChatMessage> messages;
  final Conversation? conversation;
  final bool isLoading;
  final bool isSending;
  final bool hasMore;
  final String? cursor;
  final String? error;
  final bool needsRekey;

  ConversationState copyWith({
    List<ChatMessage>? messages,
    Conversation? conversation,
    bool? isLoading,
    bool? isSending,
    bool? hasMore,
    String? cursor,
    String? error,
    bool? needsRekey,
  }) => ConversationState(
    messages: messages ?? this.messages,
    conversation: conversation ?? this.conversation,
    isLoading: isLoading ?? this.isLoading,
    isSending: isSending ?? this.isSending,
    hasMore: hasMore ?? this.hasMore,
    cursor: cursor ?? this.cursor,
    error: error,
    needsRekey: needsRekey ?? false,
  );
}

final conversationProvider =
    NotifierProvider.family<ConversationNotifier, ConversationState, String>(
      ConversationNotifier.new,
    );

class ConversationNotifier extends FamilyNotifier<ConversationState, String> {
  Timer? _poll;
  Uint8List? _cek;
  DateTime? _lastTyping;
  int _pendingSeq = 0;

  @override
  ConversationState build(String conversationId) {
    ref.onDispose(() => _poll?.cancel());
    unawaited(_open(conversationId));
    return const ConversationState();
  }

  ChatCrypto get _crypto => ref.read(chatCryptoProvider);

  ChatRepository get _repository => ref.read(chatRepositoryProvider);

  Future<void> _open(String conversationId) async {
    final identity = await ref.read(chatIdentityProvider.future);
    if (identity == null) return;

    final result = await _repository.conversation(conversationId);
    final conversation = result.valueOrNull;
    if (conversation == null) {
      state = state.copyWith(isLoading: false, error: 'Could not open this chat.');
      return;
    }

    final peer = await _repository.identityOf(conversation.other.username);
    final wrapped = conversation.wrappedCek;
    final peerKey = peer.valueOrNull?.publicKey;
    final me = ref.read(authProvider).user!.userId;

    if (wrapped != null && peerKey != null) {
      try {
        _cek = await _crypto.unwrapFromPeer(
          wrapped: wrapped,
          mine: identity,
          theirPublicKey: peerKey,
          pair: ChatCrypto.pairKey(me, conversation.other.userId),
          recipientId: me,
        );
      } catch (_) {
        state = state.copyWith(
          isLoading: false,
          conversation: conversation,
          error: 'The keys for this chat changed, so nothing here can be opened. '
              'Resetting starts it fresh and clears what came before.',
          needsRekey: true,
        );
        return;
      }
    }

    state = state.copyWith(conversation: conversation, isLoading: false);
    await _loadLatest();
    _startPolling();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _tick());
  }

  Future<void> _tick() async {
    await _pollNew();
    final refreshed = await _repository.conversation(arg);
    final conversation = refreshed.valueOrNull;
    if (conversation != null) state = state.copyWith(conversation: conversation);
  }

  Future<void> announceTyping() async {
    final now = DateTime.now();
    if (_lastTyping != null && now.difference(_lastTyping!).inSeconds < 4) return;
    _lastTyping = now;
    await _repository.typing(arg);
  }

  Future<List<ChatMessage>> _decorate(List<ChatMessage> raw) async {
    final cek = _cek;
    if (cek == null) return raw;

    final decorated = <ChatMessage>[];
    for (final message in raw) {
      if (message.isDeleted || message.ciphertext == null) {
        decorated.add(message);
        continue;
      }
      try {
        decorated.add(
          message.withText(
            await _crypto.decryptMessage(
              cek: cek,
              ciphertext: message.ciphertext!,
              conversationId: arg,
            ),
          ),
        );
      } catch (_) {
        decorated.add(message.withText(null));
      }
    }
    return decorated;
  }

  Future<void> _loadLatest() async {
    final result = await _repository.messages(arg);
    final raw = result.valueOrNull ?? const <ChatMessage>[];
    final decorated = await _decorate(raw);

    state = state.copyWith(
      messages: decorated,
      hasMore: raw.length >= 30,
      cursor: raw.isEmpty ? null : raw.last.messageId,
    );
    await _markRead();
  }

  Future<void> _pollNew() async {
    final newest = state.messages.where((m) => !m.isSending).firstOrNull;
    if (newest == null) return;

    final result = await _repository.messages(arg, after: newest.messageId);
    final fresh = result.valueOrNull ?? const <ChatMessage>[];
    if (fresh.isEmpty) return;

    final decorated = await _decorate(fresh.reversed.toList());
    state = state.copyWith(messages: [...decorated, ...state.messages]);
    await _markRead();
  }

  Future<void> loadOlder() async {
    if (!state.hasMore || state.cursor == null) return;

    final result = await _repository.messages(arg, cursor: state.cursor);
    final raw = result.valueOrNull ?? const <ChatMessage>[];
    final decorated = await _decorate(raw);

    state = state.copyWith(
      messages: [...state.messages, ...decorated],
      hasMore: raw.length >= 30,
      cursor: raw.isEmpty ? state.cursor : raw.last.messageId,
    );
  }

  Future<void> _markRead() async {
    final newest = state.messages.where((m) => !m.isSending).firstOrNull;
    if (newest == null) return;
    await _repository.markRead(arg, newest.messageId);
    ref.invalidate(chatUnreadProvider);
  }

  Future<bool> send(String text, {String? replyTo}) async {
    final cek = _cek;
    final me = ref.read(authProvider).user;
    if (cek == null || me == null || text.trim().isEmpty) return false;

    final placeholder = ChatMessage(
      messageId: 'pending_${++_pendingSeq}',
      conversationId: arg,
      senderId: me.userId,
      isDeleted: false,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      reactions: const [],
      replyTo: replyTo,
      text: text.trim(),
      isSending: true,
    );
    state = state.copyWith(messages: [placeholder, ...state.messages]);

    final ciphertext = await _crypto.encryptMessage(
      cek: cek,
      text: text.trim(),
      conversationId: arg,
    );
    final result = await _repository.send(
      conversationId: arg,
      ciphertext: ciphertext,
      replyTo: replyTo,
    );

    final sent = result.valueOrNull;
    state = state.copyWith(
      messages: [
        for (final message in state.messages)
          if (message.messageId != placeholder.messageId)
            message
          else if (sent != null)
            sent.withText(text.trim())
          else
            placeholder.asPending(failed: true),
      ],
    );

    ref.invalidate(conversationsProvider(null));
    return sent != null;
  }

  Future<void> unsend(String messageId) async {
    await _repository.unsend(arg, messageId);
    await _loadLatest();
  }

  Future<void> react(String messageId, String? emoji) async {
    if (emoji == null) {
      await _repository.clearReaction(arg, messageId);
    } else {
      await _repository.react(arg, messageId, emoji);
    }
    await _loadLatest();
  }

  Future<bool> rekey() async {
    final identity = await ref.read(chatIdentityProvider.future);
    final conversation = state.conversation;
    final me = ref.read(authProvider).user;
    if (identity == null || conversation == null || me == null) return false;

    final peer = (await _repository.identityOf(conversation.other.username)).valueOrNull;
    if (peer == null) return false;

    final cek = await _crypto.newConversationKey();
    final pair = ChatCrypto.pairKey(me.userId, peer.userId);

    final done = await _repository.rekey(
      conversationId: arg,
      wrappedForMe: await _crypto.wrapForPeer(
        cek: cek,
        mine: identity,
        theirPublicKey: peer.publicKey,
        pair: pair,
        recipientId: me.userId,
      ),
      wrappedForThem: await _crypto.wrapForPeer(
        cek: cek,
        mine: identity,
        theirPublicKey: peer.publicKey,
        pair: pair,
        recipientId: peer.userId,
      ),
      senderPublicKey: identity.publicKey,
    );

    if (done.valueOrNull != true) return false;

    _cek = cek;
    state = state.copyWith(messages: const [], needsRekey: false);
    await _loadLatest();
    _startPolling();
    return true;
  }

  Future<void> accept() async {
    await _repository.accept(arg);
    ref.invalidate(conversationsProvider(null));
    ref.invalidate(conversationsProvider('pending'));
    await _open(arg);
  }
}

final chatStarterProvider = Provider<ChatStarter>(ChatStarter.new);

class ChatStarter {
  ChatStarter(this._ref);

  final Ref _ref;

  Future<String?> open(String username) async {
    final identity = await _ref.read(chatIdentityProvider.future);
    final me = _ref.read(authProvider).user;
    if (identity == null || me == null) return null;

    final repository = _ref.read(chatRepositoryProvider);
    final crypto = _ref.read(chatCryptoProvider);

    final existing = await repository.conversations();
    for (final conversation in existing.valueOrNull ?? const <Conversation>[]) {
      if (conversation.other.username.toLowerCase() == username.toLowerCase()) {
        return conversation.conversationId;
      }
    }

    final peer = (await repository.identityOf(username)).valueOrNull;
    if (peer == null) return null;

    final cek = await crypto.newConversationKey();
    final pair = ChatCrypto.pairKey(me.userId, peer.userId);

    final started = await repository.start(
      username: username,
      wrappedForMe: await crypto.wrapForPeer(
        cek: cek,
        mine: identity,
        theirPublicKey: peer.publicKey,
        pair: pair,
        recipientId: me.userId,
      ),
      wrappedForThem: await crypto.wrapForPeer(
        cek: cek,
        mine: identity,
        theirPublicKey: peer.publicKey,
        pair: pair,
        recipientId: peer.userId,
      ),
      senderPublicKey: identity.publicKey,
    );

    _ref.invalidate(conversationsProvider(null));
    return started.valueOrNull?.conversationId;
  }
}


final presenceHeartbeatProvider = Provider<PresenceHeartbeat>((ref) {
  final beat = PresenceHeartbeat(ref);
  ref.onDispose(beat.stop);
  return beat;
});

class PresenceHeartbeat {
  PresenceHeartbeat(this._ref);

  final Ref _ref;
  Timer? _timer;

  void start() {
    if (_timer != null) return;
    unawaited(_beat());
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _beat());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _beat() async {
    if (_ref.read(authProvider).user == null) return;
    await _ref.read(chatRepositoryProvider).heartbeat();
  }
}


final chatBootstrapProvider = Provider<ChatBootstrap>(ChatBootstrap.new);

class ChatBootstrap {
  ChatBootstrap(this._ref);

  final Ref _ref;

  Future<void> afterSignIn({
    required String userId,
    required String password,
  }) async {
    final store = _ref.read(secureStoreProvider);
    final crypto = _ref.read(chatCryptoProvider);
    final repository = _ref.read(chatRepositoryProvider);

    final existing = await repository.backup();
    final backup = existing.valueOrNull;

    if (backup != null) {
      try {
        final identity = await crypto.unwrapIdentity(
          wrapped: backup.wrappedPrivateKey,
          password: password,
          salt: backup.salt,
          userId: userId,
        );
        await store.saveChatKey(userId, identity.privateKey);
        await repository.publishIdentity(identity.publicKey);
        _ref.invalidate(chatIdentityProvider);
        return;
      } catch (_) {
        return;
      }
    }

    final local = await store.readChatKey(userId);
    final identity = local != null
        ? await crypto.restoreIdentity(local)
        : await crypto.newIdentity();

    final salt = await crypto.randomSalt();
    await repository.storeBackup(
      salt: salt,
      wrappedPrivateKey: await crypto.wrapIdentity(
        identity: identity,
        password: password,
        salt: salt,
        userId: userId,
      ),
      publicKey: identity.publicKey,
      kdf: const KdfParams().toJson(),
    );

    await store.saveChatKey(userId, identity.privateKey);
    _ref.invalidate(chatIdentityProvider);
  }
}
