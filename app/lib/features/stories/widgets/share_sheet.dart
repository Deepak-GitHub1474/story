import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_avatar.dart';
import '../../../components/app_button.dart';
import '../../../components/app_sheet.dart';
import '../../../components/app_toast.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/story_models.dart';
import '../providers/story_providers.dart';
import 'shared_story_card.dart';

Future<bool> showShareSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Story story,
}) async {
  final choice = await showAppSheet<String>(
    context: context,
    title: 'Share',
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ShareOption(
            icon: Icons.repeat_rounded,
            label: 'Add to your story',
            hint: 'Post it on your profile with a note of your own',
            onTap: () => Navigator.of(sheetContext).pop('reshare'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ShareOption(
            icon: Icons.link_rounded,
            label: 'Copy link',
            hint: 'Anyone with the link can read it',
            onTap: () => Navigator.of(sheetContext).pop('link'),
          ),
        ],
      ),
    ),
  );

  if (choice == null || !context.mounted) return false;

  if (choice == 'link') {
    final result = await ref.read(storyRepositoryProvider).share(story.storyId);
    if (!context.mounted) return false;

    final url = result.valueOrNull;
    if (url == null) {
      AppToast.show(
        context,
        result.failureOrNull!.message,
        kind: AppToastKind.error,
      );
      return false;
    }

    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return false;
    AppToast.show(context, 'Link copied.', kind: AppToastKind.success);
    return false;
  }

  final posted = await showAppSheet<bool>(
    context: context,
    title: 'Add to your story',
    builder: (sheetContext) => _ReshareComposer(story: story),
  );

  return posted ?? false;
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
              ),
              child: Icon(icon, size: AppSizes.iconMd, color: colors.textPrimary),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: AppTypeScale.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: AppTypeScale.caption,
                      height: 1.4,
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

class _ReshareComposer extends ConsumerStatefulWidget {
  const _ReshareComposer({required this.story});

  final Story story;

  @override
  ConsumerState<_ReshareComposer> createState() => _ReshareComposerState();
}

class _ReshareComposerState extends ConsumerState<_ReshareComposer> {
  final _controller = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  SharedStory get _quoted {
    final origin = widget.story.shared;
    if (origin != null) return origin;

    return SharedStory(
      storyId: widget.story.storyId,
      title: widget.story.title,
      excerpt: widget.story.excerpt,
      slug: widget.story.slug,
      author: widget.story.author,
    );
  }

  Future<void> _post() async {
    setState(() => _isPosting = true);

    final repository = ref.read(storyRepositoryProvider);
    final created = await repository.create(
      body: _controller.text.trim(),
      sharedStoryId: widget.story.storyId,
    );

    final draft = created.valueOrNull;
    if (draft == null) {
      if (!mounted) return;
      setState(() => _isPosting = false);
      AppToast.show(
        context,
        created.failureOrNull!.message,
        kind: AppToastKind.error,
      );
      return;
    }

    final published = await repository.publish(
      draft.storyId,
      visibility: 'public',
    );

    if (!mounted) return;
    setState(() => _isPosting = false);

    published.fold(
      onSuccess: (_) {
        Navigator.of(context).pop(true);
        AppToast.show(context, 'Added to your story.', kind: AppToastKind.success);
      },
      onFailure: (failure) =>
          AppToast.show(context, failure.message, kind: AppToastKind.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final me = ref.watch(authProvider).user;
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xl + insets,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(
                seed: me?.avatarSeed ?? '',
                size: 34,
                displayName: me?.displayName,
                username: me?.username,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: 5,
                  minLines: 2,
                  maxLength: 600,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: AppTypeScale.reading,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    border: InputBorder.none,
                    hintText: 'Say something about this…',
                    hintStyle: TextStyle(
                      color: colors.textMuted,
                      fontSize: AppTypeScale.reading,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SharedStoryCard(shared: _quoted),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Your note is posted as your own story. Theirs stays theirs, and '
            'editing yours never touches it.',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: AppTypeScale.caption,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Post',
            isLoading: _isPosting,
            onPressed: _isPosting ? null : _post,
          ),
        ],
      ),
    );
  }
}
