import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_avatar.dart';
import '../../../components/app_toast.dart';
import '../../../components/skeleton.dart';
import '../../../core/api/endpoints.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../../communities/models/community_models.dart';

enum PeopleKind { following, followers, blocked }

final peopleProvider =
    FutureProvider.family<List<PublicProfile>, PeopleKind>((ref, kind) async {
      final path = switch (kind) {
        PeopleKind.following => Endpoints.following,
        PeopleKind.followers => Endpoints.followers,
        PeopleKind.blocked => Endpoints.blocked,
      };

      final result = await ref.watch(apiClientProvider).get<List<PublicProfile>>(
        path,
        parse: (data) => (data['items'] as List<dynamic>)
            .map((item) => PublicProfile.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
      );
      return result.valueOrNull ?? const [];
    });

class PeopleListScreen extends ConsumerWidget {
  const PeopleListScreen({super.key, required this.kind});

  final PeopleKind kind;

  String get _title => switch (kind) {
    PeopleKind.following => 'Following',
    PeopleKind.followers => 'Followers',
    PeopleKind.blocked => 'Blocked accounts',
  };

  String get _emptyBody => switch (kind) {
    PeopleKind.following => 'When you follow someone, their stories move to the top of yours.',
    PeopleKind.followers => 'People who follow you appear here.',
    PeopleKind.blocked => 'Blocked accounts cannot see you and you cannot see them.',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final people = ref.watch(peopleProvider(kind));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(_title),
      ),
      body: SafeArea(
        child: people.when(
          loading: () => const SkeletonList(count: 5),
          error: (error, _) => Center(
            child: Text(
              'Could not load this list.',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          data: (items) => items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          kind == PeopleKind.blocked
                              ? Icons.block
                              : Icons.people_outline,
                          size: 44,
                          color: colors.textMuted,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Nobody here yet',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: AppTypeScale.heading,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _emptyBody,
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
                )
              : RefreshIndicator(
                  color: colors.accent,
                  backgroundColor: colors.surface,
                  onRefresh: () async => ref.invalidate(peopleProvider(kind)),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: colors.border),
                    itemBuilder: (context, index) {
                      final person = items[index];
                      return ListTile(
                        leading: AppAvatar(
                          seed: person.avatarSeed,
                          size: 40,
                          displayName: person.displayName,
                          username: person.username,
                        ),
                        title: Text(
                          person.displayName,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '@${person.username}',
                          style: TextStyle(color: colors.textMuted),
                        ),
                        trailing: kind == PeopleKind.blocked
                            ? TextButton(
                                onPressed: () async {
                                  await ref
                                      .read(apiClientProvider)
                                      .delete<bool>(
                                        '${Endpoints.connection(person.username)}/block',
                                        parse: (data) => true,
                                      );
                                  ref.invalidate(peopleProvider(kind));
                                  if (context.mounted) {
                                    AppToast.show(context, 'Unblocked.');
                                  }
                                },
                                child: Text(
                                  'Unblock',
                                  style: TextStyle(color: colors.accent),
                                ),
                              )
                            : null,
                        onTap: () => context.push('${Routes.user}/${person.username}'),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}
