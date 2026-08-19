import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_avatar.dart';
import '../../../components/app_button.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/app_toast.dart';
import '../../../core/utils/avatar_seeds.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../../stories/models/story_models.dart';
import '../../stories/providers/story_providers.dart';
import '../providers/settings_provider.dart';

class AvatarScreen extends ConsumerStatefulWidget {
  const AvatarScreen({super.key});

  @override
  ConsumerState<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends ConsumerState<AvatarScreen> {
  late List<String> _seeds;
  late String _chosen;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(authProvider).user?.avatarSeed ?? '';
    _chosen = current;
    _seeds = faceSeeds(keep: current);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final result = await ref
        .read(profileRepositoryProvider)
        .updateProfile(avatarSeed: _chosen);

    if (!mounted) return;
    setState(() => _isSaving = false);

    await ref.read(authProvider.notifier).refreshUser();
    if (!mounted) return;
    final me = ref.read(authProvider).user;
    if (me != null) {
      retintAuthorEverywhere(
        ref,
        StoryAuthor(
          userId: me.userId,
          username: me.username,
          displayName: me.displayName,
          avatarSeed: me.avatarSeed,
        ),
      );
    }

    result.fold(
      onSuccess: (_) {
        AppToast.show(context, 'Avatar saved.', kind: AppToastKind.success);
        context.pop();
      },
      onFailure: (failure) =>
          AppToast.show(context, failure.message, kind: AppToastKind.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(authProvider).user;

    return AppScaffold(
      title: 'Your avatar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                seed: _chosen,
                size: 72,
                displayName: user?.displayName,
                username: user?.username,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user?.displayName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: AppTypeScale.body,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user?.username ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: AppTypeScale.label,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppSpacing.xl,
                crossAxisSpacing: AppSpacing.lg,
              ),
              itemCount: _seeds.length,
              itemBuilder: (context, index) {
                final seed = _seeds[index];
                final isChosen = seed == _chosen;

                return GestureDetector(
                  onTap: () => setState(() => _chosen = seed),
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    curve: AppMotion.easeOut,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isChosen ? colors.accent : Colors.transparent,
                        width: 2.4,
                      ),
                    ),
                    child: AppAvatar(
                      seed: seed,
                      size: 72,
                      displayName: user?.displayName,
                      username: user?.username,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Use this avatar',
            isLoading: _isSaving,
            onPressed: _chosen.isEmpty ? null : _save,
          ),
        ],
      ),
    );
  }
}
