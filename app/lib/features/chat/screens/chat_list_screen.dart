import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_avatar.dart';
import '../../../components/skeleton.dart';
import '../../../core/utils/time_ago.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/chat_models.dart';
import '../providers/chat_providers.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  bool _showRequests = false;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      ref.invalidate(conversationsProvider(_showRequests ? 'pending' : null));
      ref.invalidate(chatUnreadProvider);
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unread = ref.watch(chatUnreadProvider).valueOrNull;
    final conversations = ref.watch(
      conversationsProvider(_showRequests ? 'pending' : null),
    );

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Text(
                  'Messages',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: AppTypeScale.title,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: colors.textPrimary),
                  onPressed: () => context.push(Routes.search),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                _Segment(
                  label: 'Chats',
                  isActive: !_showRequests,
                  onTap: () => setState(() => _showRequests = false),
                ),
                const SizedBox(width: AppSpacing.sm),
                _Segment(
                  label: unread != null && unread.requests > 0
                      ? 'Requests (${unread.requests})'
                      : 'Requests',
                  isActive: _showRequests,
                  onTap: () => setState(() => _showRequests = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: conversations.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: 6,
                itemBuilder: (context, index) => const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.lg),
                  child: SkeletonBox(height: 56, width: double.infinity),
                ),
              ),
              error: (_, _) => _Empty(
                title: 'Could not load your messages',
                body: 'Check your connection and pull to refresh.',
              ),
              data: (items) => items.isEmpty
                  ? _Empty(
                      title: _showRequests ? 'No requests' : 'No messages yet',
                      body: _showRequests
                          ? 'People who do not follow you back land here first.'
                          : 'Find someone from search and say something. '
                                'If you both follow each other it opens straight away.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(
                          conversationsProvider(_showRequests ? 'pending' : null),
                        );
                        ref.invalidate(chatUnreadProvider);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        itemCount: items.length,
                        itemBuilder: (context, index) => _ConversationRow(
                          conversation: items[index],
                          onTap: () => context.push(
                            '${Routes.chat}/${items[index].conversationId}',
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.isActive, required this.onTap});

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive ? colors.accent : colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: isActive ? colors.accent : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? colors.accentText : colors.textSecondary,
            fontSize: AppTypeScale.label,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unread = conversation.unreadCount;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            AppAvatar(
              seed: conversation.other.avatarSeed,
              size: 52,
              displayName: conversation.other.displayName,
              username: conversation.other.username,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.other.displayName,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: AppTypeScale.body,
                      fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    conversation.isPending
                        ? conversation.isRequester
                              ? 'Request sent'
                              : 'Wants to send you a message'
                        : '@${conversation.other.username}',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: AppTypeScale.caption,
                    ),
                  ),
                ],
              ),
            ),
            if (conversation.lastMessageAt != null)
              Text(
                timeAgo(conversation.lastMessageAt!),
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: AppTypeScale.caption,
                ),
              ),
            if (unread > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$unread',
                  style: TextStyle(
                    color: colors.accentText,
                    fontSize: AppTypeScale.caption,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 44, color: colors.textMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: AppTypeScale.heading,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
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
