import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_avatar.dart';
import '../../../core/utils/time_ago.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/notification_models.dart';
import '../providers/notification_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);

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
                  'Activity',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: AppTypeScale.heading,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (unread > 0)
                  TextButton(
                    onPressed: () =>
                        ref.read(notificationsProvider.notifier).markAllRead(),
                    child: Text(
                      'Mark all read',
                      style: TextStyle(color: colors.accent),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: notifications.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  'Could not load your activity.',
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
                          return Dismissible(
                            key: ValueKey(notification.notificationId),
                            background: _SwipeHint(
                              icon: Icons.mark_email_read_outlined,
                              label: 'Read',
                              alignment: Alignment.centerLeft,
                            ),
                            secondaryBackground: const _SwipeHint(
                              icon: Icons.delete_outline,
                              label: 'Clear',
                              alignment: Alignment.centerRight,
                              isDanger: true,
                            ),
                            confirmDismiss: (direction) async {
                              final notifier = ref.read(
                                notificationsProvider.notifier,
                              );
                              if (direction == DismissDirection.endToStart) {
                                await notifier.remove(notification.notificationId);
                                return true;
                              }
                              await notifier.markRead(notification.notificationId);
                              return false;
                            },
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
    final screen = const NotificationsScreen();

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
                        screen._icon(notification.kind),
                        size: 12,
                        color: screen._iconColor(context, notification.kind),
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
                              fontWeight: FontWeight.w600,
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
              fontWeight: FontWeight.w600,
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

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({
    required this.icon,
    required this.label,
    required this.alignment,
    this.isDanger = false,
  });

  final IconData icon;
  final String label;
  final Alignment alignment;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = isDanger ? colors.danger : colors.accent;

    return Container(
      color: tint.withValues(alpha: 0.12),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconMd, color: tint),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontSize: AppTypeScale.label,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
