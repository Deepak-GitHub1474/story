import 'package:flutter/material.dart';

import '../../../core/utils/chat_time.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/chat_models.dart';

class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.isSeen,
    required this.onLongPress,
    required this.onDoubleTap,
    required this.onReplySwipe,
    this.repliedTo,
    this.onTapReplied,
    this.myReaction,
    this.isHighlighted = false,
    this.showSeenLabel = false,
    this.repliedToAuthor,
  });

  final ChatMessage message;
  final bool isMine;
  final bool isSeen;
  final ChatMessage? repliedTo;
  final VoidCallback onLongPress;
  final VoidCallback onDoubleTap;
  final VoidCallback onReplySwipe;
  final VoidCallback? onTapReplied;
  final String? myReaction;
  final bool isHighlighted;
  final bool showSeenLabel;
  final String? repliedToAuthor;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.base,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isEmojiOnly {
    final text = widget.message.text;
    if (text == null || text.isEmpty || text.characters.length > 3) return false;
    return !RegExp(r'[0-9a-zA-Z]').hasMatch(text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final message = widget.message;
    final isMine = widget.isMine;

    final body = message.text == null
        ? Text(
            'Cannot be opened on this device',
            style: TextStyle(color: colors.textMuted, fontSize: AppTypeScale.caption),
          )
        : Text(
            message.text!,
            style: TextStyle(
              color: _isEmojiOnly
                  ? colors.textPrimary
                  : isMine
                  ? colors.accentText
                  : colors.textPrimary,
              fontSize: _isEmojiOnly ? 34 : AppTypeScale.body,
              height: _isEmojiOnly ? 1.1 : 1.4,
            ),
          );

    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: AppMotion.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(isMine ? 0.08 : -0.08, 0.12),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.easeOut)),
        child: AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.easeOut,
          color: widget.isHighlighted
              ? colors.accent.withValues(alpha: 0.14)
              : Colors.transparent,
          child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Dismissible(
                key: ValueKey('reply-${message.messageId}'),
                direction: DismissDirection.startToEnd,
                dismissThresholds: const {DismissDirection.startToEnd: 0.28},
                confirmDismiss: (_) async {
                  widget.onReplySwipe();
                  return false;
                },
                background: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.reply,
                      size: AppSizes.iconSm,
                      color: colors.accent,
                    ),
                  ),
                ),
                child: GestureDetector(
                onLongPress: widget.onLongPress,
                onDoubleTap: widget.onDoubleTap,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.76,
                  ),
                  child: Container(
                    padding: _isEmojiOnly
                        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                        : const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                    decoration: _isEmojiOnly
                        ? null
                        : BoxDecoration(
                            color: isMine ? colors.accent : colors.surface,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(AppRadius.lg),
                              topRight: const Radius.circular(AppRadius.lg),
                              bottomLeft: Radius.circular(
                                isMine ? AppRadius.lg : AppRadius.sm,
                              ),
                              bottomRight: Radius.circular(
                                isMine ? AppRadius.sm : AppRadius.lg,
                              ),
                            ),
                            border: isMine
                                ? null
                                : Border.all(color: colors.border),
                          ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.repliedTo != null) ...[
                          GestureDetector(
                            onTap: widget.onTapReplied,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 5),
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: isMine
                                    ? colors.accentText.withValues(alpha: 0.14)
                                    : colors.surfaceRaised,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      width: 3,
                                      color: isMine
                                          ? colors.accentText
                                          : colors.accent,
                                    ),
                                    Flexible(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(7, 5, 8, 5),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              widget.repliedToAuthor ?? 'Message',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isMine
                                                    ? colors.accentText
                                                    : colors.accent,
                                                fontSize: AppTypeScale.caption,
                                                fontWeight: FontWeight.w500,
                                                height: 1.25,
                                              ),
                                            ),
                                            Text(
                                              widget.repliedTo!.text ?? 'Message',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isMine
                                                    ? colors.accentText.withValues(
                                                        alpha: 0.85,
                                                      )
                                                    : colors.textSecondary,
                                                fontSize: AppTypeScale.caption,
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        body,
                      ],
                    ),
                  ),
                ),
                ),
              ),
              if (message.reactions.isNotEmpty)
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.surfaceRaised,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      message.reactions.map((r) => r.emoji).join(),
                      style: const TextStyle(fontSize: AppTypeScale.label),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.isSending
                          ? 'Sending'
                          : message.hasFailed
                          ? 'Not sent'
                          : widget.showSeenLabel
                          ? 'Seen'
                          : message.editedAt != null
                          ? '${messageClock(message.createdAt)} · edited'
                          : messageClock(message.createdAt),
                      style: TextStyle(
                        color: message.hasFailed ? colors.danger : colors.textMuted,
                        fontSize: AppTypeScale.caption,
                      ),
                    ),
                    if (isMine && !message.hasFailed) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.isSending
                            ? Icons.schedule
                            : widget.isSeen
                            ? Icons.done_all
                            : Icons.done,
                        size: 13,
                        color: widget.isSeen && !message.isSending
                            ? colors.accent
                            : colors.textMuted,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
