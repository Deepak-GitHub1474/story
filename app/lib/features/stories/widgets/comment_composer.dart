import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

class CommentComposer extends StatelessWidget {
  const CommentComposer({
    super.key,
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.replyingTo,
    required this.onCancelReply,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final String? replyingTo;
  final VoidCallback onCancelReply;

  static const quickEmoji = ['❤️', '🫂', '😢', '🙏', '💛', '✨'];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canSend = controller.text.trim().isNotEmpty && !isSending;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: AppMotion.fast,
              curve: AppMotion.easeOut,
              child: replyingTo == null
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      color: colors.surfaceRaised,
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply,
                            size: AppSizes.iconSm,
                            color: colors.textMuted,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Replying to $replyingTo',
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
                              size: AppSizes.iconSm,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: quickEmoji.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) => _EmojiChip(
                  emoji: quickEmoji[index],
                  onTap: () {
                    controller.text = '${controller.text}${quickEmoji[index]}';
                    controller.selection = TextSelection.collapsed(
                      offset: controller.text.length,
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 4,
                      minLines: 1,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Say something kind',
                        hintStyle: TextStyle(color: colors.textMuted),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  AnimatedScale(
                    scale: canSend ? 1 : 0.85,
                    duration: AppMotion.fast,
                    curve: AppMotion.easeOut,
                    child: IconButton(
                      icon: isSending
                          ? const SizedBox(
                              width: AppSizes.iconSm,
                              height: AppSizes.iconSm,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: canSend ? colors.accent : colors.textMuted,
                            ),
                      onPressed: canSend ? onSend : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiChip extends StatelessWidget {
  const _EmojiChip({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}
