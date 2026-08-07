import 'package:flutter/material.dart';

import '../../../components/app_sheet.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_avatar.dart';
import '../../../components/app_button.dart';
import '../../../components/app_toast.dart';
import '../../../components/confirm_dialog.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chat_models.dart';
import '../providers/chat_providers.dart';
import '../widgets/message_bubble.dart';

const quickReactions = ['❤️', '😂', '😮', '😢', '🙏', '🔥'];

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  ChatMessage? _replyTo;
  final _keys = <String, GlobalKey>{};

  GlobalKey _keyFor(String messageId) =>
      _keys.putIfAbsent(messageId, GlobalKey.new);

  void _scrollTo(String messageId) {
    final target = _keys[messageId]?.currentContext;
    if (target == null) return;

    Scrollable.ensureVisible(
      target,
      duration: AppMotion.base,
      curve: AppMotion.easeOut,
      alignment: 0.4,
    );
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _composer.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      ref.read(conversationProvider(widget.conversationId).notifier).loadOlder();
    }
  }

  Future<void> _send() async {
    final text = _composer.text;
    if (text.trim().isEmpty) return;

    _composer.clear();
    final reply = _replyTo;
    setState(() => _replyTo = null);

    final ok = await ref
        .read(conversationProvider(widget.conversationId).notifier)
        .send(text, replyTo: reply?.messageId);

    if (!ok && mounted) {
      AppToast.show(context, 'That did not send.', kind: AppToastKind.error);
    }
  }

  Future<void> _openMessageMenu(ChatMessage message, bool isMine) async {
    final colors = context.colors;
    final me = ref.read(authProvider).user?.userId ?? '';

    await showAppSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final emoji in quickReactions)
                    _ReactionButton(
                      emoji: emoji,
                      isChosen: message.reactions.any(
                        (r) => r.emoji == emoji && r.userId == me,
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        final already = message.reactions.any(
                          (r) => r.emoji == emoji && r.userId == me,
                        );
                        ref
                            .read(
                              conversationProvider(widget.conversationId).notifier,
                            )
                            .react(message.messageId, already ? null : emoji);
                      },
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.border),
            ListTile(
              leading: Icon(Icons.reply_outlined, color: colors.textPrimary),
              title: const Text('Reply'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                setState(() => _replyTo = message);
                _focus.requestFocus();
              },
            ),
            if (message.text != null)
              ListTile(
                leading: Icon(Icons.copy_outlined, color: colors.textPrimary),
                title: const Text('Copy'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Clipboard.setData(ClipboardData(text: message.text!));
                  if (mounted) AppToast.show(context, 'Copied.');
                },
              ),
            if (isMine)
              ListTile(
                leading: Icon(Icons.delete_outline, color: colors.danger),
                title: Text('Unsend', style: TextStyle(color: colors.danger)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref
                      .read(conversationProvider(widget.conversationId).notifier)
                      .unsend(message.messageId);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(conversationProvider(widget.conversationId));
    final me = ref.watch(authProvider).user?.userId ?? '';
    final other = state.conversation?.other;
    final isPending = state.conversation?.isPending ?? false;
    final canWrite = !isPending || (state.conversation?.isRequester ?? false);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: other == null
            ? const SizedBox.shrink()
            : InkWell(
                onTap: () => context.push('${Routes.user}/${other.username}'),
                child: Row(
                  children: [
                    AppAvatar(
                      seed: other.avatarSeed,
                      size: 34,
                      displayName: other.displayName,
                      username: other.username,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          other.displayName,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: AppTypeScale.body,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _PresenceLine(
                          username: other.username,
                          isOnline: state.conversation?.otherOnline,
                          isTyping: state.conversation?.otherTyping ?? false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: colors.textMuted),
            onPressed: () async {
              final confirmed = await confirmAction(
                context,
                title: 'Delete this chat?',
                body: 'It disappears from your list. The other person keeps theirs.',
                confirmLabel: 'Delete',
                cancelLabel: 'Keep',
              );
              if (!confirmed || !context.mounted) return;
              await ref
                  .read(chatRepositoryProvider)
                  .removeConversation(widget.conversationId);
              ref.invalidate(conversationsProvider(null));
              if (context.mounted) context.pop();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (state.error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                color: colors.surfaceRaised,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.error!,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: AppTypeScale.label,
                        height: 1.5,
                      ),
                    ),
                    if (state.needsRekey) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Reset this chat',
                        variant: AppButtonVariant.secondary,
                        onPressed: () async {
                          final ok = await ref
                              .read(
                                conversationProvider(widget.conversationId).notifier,
                              )
                              .rekey();
                          if (!context.mounted) return;
                          AppToast.show(
                            context,
                            ok
                                ? 'Fresh key. You can talk again.'
                                : 'Could not reset. They may need to open the app.',
                            kind: ok ? AppToastKind.success : AppToastKind.error,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : state.messages.isEmpty
                  ? SingleChildScrollView(
                      child: _EmptyThread(name: other?.displayName ?? 'them'),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final message = state.messages[index];
                        final isMine = message.senderId == me;
                        final seen =
                            isMine &&
                            state.conversation?.theirLastReadMessageId != null &&
                            message.messageId.compareTo(
                                  state.conversation!.theirLastReadMessageId!,
                                ) <=
                                0;
                        final mine = message.reactions
                            .where((r) => r.userId == me)
                            .firstOrNull;
                        return MessageBubble(
                          key: _keyFor(message.messageId),
                          myReaction: mine?.emoji,
                          onReplySwipe: () {
                            setState(() => _replyTo = message);
                            _focus.requestFocus();
                          },
                          onTapReplied: () => _scrollTo(message.replyTo!),
                          message: message,
                          isMine: isMine,
                          isSeen: seen,
                          repliedTo: message.replyTo == null
                              ? null
                              : state.messages
                                    .where((m) => m.messageId == message.replyTo)
                                    .firstOrNull,
                          onLongPress: () => _openMessageMenu(message, isMine),
                          onDoubleTap: () => ref
                              .read(
                                conversationProvider(widget.conversationId).notifier,
                              )
                              .react(message.messageId, '❤️'),
                        );
                      },
                    ),
            ),
            if (isPending && !(state.conversation?.isRequester ?? false))
              _RequestBar(
                name: other?.displayName ?? 'They',
                onAccept: () => ref
                    .read(conversationProvider(widget.conversationId).notifier)
                    .accept(),
              )
            else if (canWrite)
              _Composer(
                controller: _composer,
                focusNode: _focus,
                replyTo: _replyTo,
                onCancelReply: () => setState(() => _replyTo = null),
                onSend: _send,
                onTyping: (_) => ref
                    .read(conversationProvider(widget.conversationId).notifier)
                    .announceTyping(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReactionButton extends StatefulWidget {
  const _ReactionButton({
    required this.emoji,
    required this.onTap,
    this.isChosen = false,
  });

  final String emoji;
  final VoidCallback onTap;
  final bool isChosen;

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 1.4),
      onTapUp: (_) {
        setState(() => _scale = 1);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1),
      child: AnimatedScale(
        scale: _scale,
        duration: AppMotion.fast,
        curve: AppMotion.easeOut,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isChosen
                ? context.colors.accent.withValues(alpha: 0.18)
                : Colors.transparent,
          ),
          child: Text(widget.emoji, style: const TextStyle(fontSize: 28)),
        ),
      ),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 36, color: colors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nothing here yet',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: AppTypeScale.heading,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Messages between you and $name are encrypted on this device. '
              'We store only ciphertext and cannot read any of it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: AppTypeScale.body,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestBar extends StatelessWidget {
  const _RequestBar({required this.name, required this.onAccept});

  final String name;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        children: [
          Text(
            '$name wants to send you messages. You will not appear as read until '
            'you accept.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: AppTypeScale.label,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Accept', onPressed: onAccept),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.replyTo,
    required this.onCancelReply,
    required this.onSend,
    required this.onTyping,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ChatMessage? replyTo;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;
  final ValueChanged<String> onTyping;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? AppSpacing.sm
            : AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: AppMotion.fast,
            curve: AppMotion.easeOut,
            child: replyTo == null
                ? const SizedBox(width: double.infinity)
                : Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.surfaceRaised,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Container(width: 3, height: 28, color: colors.accent),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            replyTo!.text ?? 'Message',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: AppTypeScale.caption,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: onCancelReply,
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: AppTypeScale.body,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Message',
                    hintStyle: TextStyle(color: colors.textMuted),
                    filled: true,
                    fillColor: colors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide(color: colors.accent, width: 1.6),
                    ),
                  ),
                  onChanged: onTyping,
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SendButton(controller: controller, onSend: onSend),
            ],
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final isReady = value.text.trim().isNotEmpty;
        return AnimatedScale(
          scale: isReady ? 1 : 0.85,
          duration: AppMotion.fast,
          curve: AppMotion.easeOut,
          child: AnimatedOpacity(
            opacity: isReady ? 1 : 0.4,
            duration: AppMotion.fast,
            child: Material(
              color: colors.accent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: isReady ? onSend : null,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Icon(Icons.arrow_upward, color: colors.accentText, size: 20),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


class _PresenceLine extends StatelessWidget {
  const _PresenceLine({
    required this.username,
    required this.isOnline,
    required this.isTyping,
  });

  final String username;
  final bool? isOnline;
  final bool isTyping;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final label = isTyping
        ? 'typing…'
        : isOnline == true
        ? 'Online'
        : '@$username';

    return AnimatedSwitcher(
      duration: AppMotion.base,
      child: Row(
        key: ValueKey(label),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isTyping || isOnline == true) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isTyping ? colors.accent : colors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: isTyping ? colors.accent : colors.textMuted,
              fontSize: AppTypeScale.caption,
              fontWeight: isTyping ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
