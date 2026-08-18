import '../../../core/identity/handle.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_avatar.dart';
import '../../../components/app_back_button.dart';
import '../../../components/app_button.dart';
import '../../../components/app_close_button.dart';
import '../../../components/app_sheet.dart';
import '../../../components/skeleton.dart';
import '../../../core/utils/time_ago.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../communities/models/community_models.dart';
import '../../communities/providers/community_providers.dart';
import '../models/chat_models.dart';
import '../providers/chat_providers.dart';
import '../widgets/unlock_chat_sheet.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  bool _showRequests = false;
  Timer? _refresh;

  Future<void> _openChatMenu(Conversation conversation) async {
    final colors = context.colors;

    final choice = await showAppSheet<String>(
      context: context,
      title: conversation.other.handle,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete_outline, color: colors.danger),
              title: Text('Delete', style: TextStyle(color: colors.danger)),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );

    if (choice != 'delete' || !mounted) return;

    await ref
        .read(chatRepositoryProvider)
        .removeConversation(conversation.conversationId);
    ref.invalidate(conversationsProvider(null));
    ref.invalidate(conversationsProvider('pending'));
    ref.invalidate(chatPeopleProvider);
  }

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
    final isLocked = ref.watch(chatLockedProvider).valueOrNull ?? false;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLocked)
            _LockedBanner(
              onUnlock: () async {
                final done = await showAppSheet<bool>(
                  context: context,
                  title: 'Unlock your messages',
                  builder: (sheetContext) => const UnlockChatSheet(),
                );
                if (done == true) ref.invalidate(chatLockedProvider);
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                AppBackButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(Routes.stories),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Messages',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: AppTypeScale.body,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.search, color: colors.textPrimary),
                  onPressed: () => context.push('${Routes.search}?people=1'),
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
                itemBuilder: (context, index) => const ConversationSkeleton(),
              ),
              error: (_, _) => _Empty(
                title: 'Could not load your messages',
                body: 'Check your connection and pull to refresh.',
              ),
              data: (items) => items.isEmpty
                  ? (_showRequests
                        ? const _Empty(
                            title: 'No requests',
                            body:
                                'People who do not follow you back land here first.',
                          )
                        : ListView(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xxxl,
                            ),
                            children: const [
                              _Empty(
                                title: 'No messages yet',
                                body:
                                    'Say something to someone you follow. If you '
                                    'both follow each other it opens straight away.',
                              ),
                              _FollowSuggestions(),
                            ],
                          ))
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(
                          conversationsProvider(
                            _showRequests ? 'pending' : null,
                          ),
                        );
                        ref.invalidate(chatUnreadProvider);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                        itemCount: items.length + 1,
                        itemBuilder: (context, index) {
                          if (index == items.length) {
                            return _showRequests
                                ? const SizedBox.shrink()
                                : const _FollowSuggestions();
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            child: _ConversationRow(
                              conversation: items[index],
                              onTap: () => context.push(
                                '${Routes.chat}/${items[index].conversationId}',
                              ),
                              onLongPress: () => _openChatMenu(items[index]),
                            ),
                          );
                        },
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
  const _Segment({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

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
          color: isActive ? colors.accentStrong : colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isActive ? colors.accentStrong : colors.border,
            width: AppSizes.hairline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? colors.accentText : colors.textSecondary,
            fontSize: AppTypeScale.label,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.onTap,
    this.onLongPress,
  });

  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unread = conversation.unreadCount;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
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
                      fontWeight: unread > 0
                          ? FontWeight.w500
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    conversation.isPending
                        ? conversation.isRequester
                              ? 'Request sent'
                              : 'Wants to send you a message'
                        : handleFor(
                                displayName: conversation.other.displayName,
                                username: conversation.other.username,
                              ) ??
                              '',
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
                    fontWeight: FontWeight.w500,
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
                fontWeight: FontWeight.w500,
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

class _LockedBanner extends StatelessWidget {
  const _LockedBanner({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: colors.accent),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your messages are locked on this phone',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: AppTypeScale.body,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Type your password once to bring them back, here and on every '
            'phone you sign in on.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: AppTypeScale.label,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Unlock messages',
            variant: AppButtonVariant.secondary,
            onPressed: onUnlock,
          ),
        ],
      ),
    );
  }
}

class _FollowSuggestions extends ConsumerStatefulWidget {
  const _FollowSuggestions();

  @override
  ConsumerState<_FollowSuggestions> createState() => _FollowSuggestionsState();
}

class _FollowSuggestionsState extends ConsumerState<_FollowSuggestions> {
  final _dismissed = <String>{};
  final _followed = <String>{};
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final suggestions = ref.watch(suggestionsProvider).valueOrNull;
    final people = (suggestions?.people ?? const [])
        .where((person) => !_dismissed.contains(person.userId))
        .toList();

    if (people.isEmpty) return const SizedBox.shrink();

    final shown = _showAll ? people : people.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'People to follow',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: AppTypeScale.body,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (people.length > 4)
                GestureDetector(
                  onTap: () => setState(() => _showAll = !_showAll),
                  child: Text(
                    _showAll ? 'Show less' : 'See all',
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: AppTypeScale.label,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (final person in shown)
          _SuggestionRow(
            person: person,
            isFollowed: _followed.contains(person.userId),
            onOpen: () =>
                context.push('${Routes.user}/${person.username ?? ''}'),
            onFollow: () async {
              setState(() => _followed.add(person.userId));
              await ref
                  .read(communityRepositoryProvider)
                  .setFollow(person.username ?? '', follow: true);
              ref.invalidate(chatPeopleProvider);
              await afterFollowChanged(ref, person.username ?? '');
            },
            onDismiss: () => setState(() => _dismissed.add(person.userId)),
          ),
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.person,
    required this.isFollowed,
    required this.onOpen,
    required this.onFollow,
    required this.onDismiss,
  });

  final SuggestedPerson person;
  final bool isFollowed;
  final VoidCallback onOpen;
  final VoidCallback onFollow;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            AppAvatar(
              seed: person.avatarSeed,
              size: 44,
              displayName: person.displayName,
              username: person.username,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: AppTypeScale.body,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    person.username == null
                        ? person.reason
                        : handleFor(
                                displayName: person.displayName,
                                username: person.username!,
                              ) ??
                              '',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: AppTypeScale.label,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: isFollowed ? null : onFollow,
              style: TextButton.styleFrom(
                backgroundColor: isFollowed
                    ? colors.surfaceRaised
                    : colors.accent,
                foregroundColor: isFollowed
                    ? colors.textMuted
                    : colors.accentText,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: Text(
                isFollowed ? 'Following' : 'Follow',
                style: const TextStyle(
                  fontSize: AppTypeScale.label,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            AppCloseButton(
              size: AppCloseSize.small,
              tooltip: 'Not now',
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
