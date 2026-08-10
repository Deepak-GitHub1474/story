import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_avatar.dart';
import '../../../core/utils/time_ago.dart';
import '../../../routing/routes.dart';
import '../../../components/skeleton.dart';
import '../../../components/swipe_to_reveal.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/notification_models.dart';
import '../providers/notification_providers.dart';

IconData _icon(String kind) => switch (kind) {
  'story_like' || 'comment_like' => Icons.favorite,
  'story_comment' => Icons.mode_comment,
  'comment_reply' => Icons.reply,
  _ => Icons.notifications,
};

Color _iconColor(BuildContext context, String kind) => switch (kind) {
  'story_like' || 'comment_like' => context.colors.danger,
  _ => context.colors.accent,
};

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _acknowledge());
  }

  void _acknowledge() {
    if (!mounted) return;
    if (ref.read(unreadCountProvider) == 0) return;
    ref.read(notificationsProvider.notifier).markAllRead();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final notifications = ref.watch(notificationsProvider);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: AppTypeScale.heading,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: notifications.when(
              loading: () => const SkeletonList(count: 6),
              error: (error, _) => Center(
                child: Text(
                  'Could not load your notifications.',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              data: (items) => items.isEmpty
                  ? _Empty()
                  : RefreshIndicator(
                      color: colors.accent,
                      backgroundColor: colors.surface,
                      onRefresh: () =>
                          ref.read(notificationsProvider.notifier).refresh(),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (context, index) =>
                            Divider(height: 1, color: colors.border),
                        itemBuilder: (context, index) {
                          final notification = items[index];
                          return SwipeToReveal(
                            key: ValueKey(notification.notificationId),
                            onDelete: () => ref
                                .read(notificationsProvider.notifier)
                                .remove(notification.notificationId),
                            child: _Tile(notification: notification),
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

class _Tile extends ConsumerWidget {
  const _Tile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Material(
      color: notification.isRead ? Colors.transparent : colors.accent.withValues(alpha: 0.06),
      child: InkWell(
        onTap: () {
          ref.read(notificationsProvider.notifier).markRead(notification.notificationId);
          if (notification.targetKind == 'story') {
            context.push('${Routes.story}/${notification.targetId}');
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(
                    seed: notification.actorAvatarSeed,
                    size: 40,
                    displayName: notification.actorName,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: colors.bg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _icon(notification.kind),
                        size: 12,
                        color: _iconColor(context, notification.kind),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: AppTypeScale.label,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: notification.actorName,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(text: notification.body),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      timeAgo(notification.createdAt),
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: AppTypeScale.caption,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListView(
      children: [
        const SizedBox(height: AppSpacing.xxxl * 2),
        Icon(Icons.notifications_none, size: 44, color: colors.textMuted),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Text(
            'Nothing yet',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: AppTypeScale.heading,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Text(
            'When someone reads and responds to your stories, it shows up here. '
            'Only things about you, nothing else.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: AppTypeScale.body,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
