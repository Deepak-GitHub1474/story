import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_avatar.dart';
import '../../../components/app_sheet.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/story_models.dart';
import '../providers/story_providers.dart';

Future<void> showLikesSheet({
  required BuildContext context,
  required String storyId,
}) => showAppSheet<void>(
  context: context,
  isResizable: true,
  initialSize: 0.7,
  title: 'Likes',
  builder: (_) => LikesSheet(storyId: storyId),
);

class LikesSheet extends ConsumerStatefulWidget {
  const LikesSheet({super.key, required this.storyId});

  final String storyId;

  @override
  ConsumerState<LikesSheet> createState() => _LikesSheetState();
}

class _LikesSheetState extends ConsumerState<LikesSheet> {
  final _people = <StoryAuthor>[];
  String? _cursor;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isFetchingMore = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final result = await ref
        .read(storyRepositoryProvider)
        .likers(widget.storyId, cursor: _cursor);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isFetchingMore = false;
      final page = result.valueOrNull;
      if (page == null) {
        _failure = result.failureOrNull?.message;
        _hasMore = false;
        return;
      }
      _people.addAll(page.items);
      _cursor = page.nextCursor;
      _hasMore = page.hasMore && page.nextCursor != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_people.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xxxl,
        ),
        child: Center(
          child: Text(
            _failure ?? 'Nobody has liked this yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: AppTypeScale.label,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final person in _people)
          ListTile(
            leading: AppAvatar(
              seed: person.avatarSeed,
              size: 40,
              displayName: person.displayName,
              username: person.username,
            ),
            title: Text(
              person.handle,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: AppTypeScale.label,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: person.username == null
                ? null
                : Text(
                    person.displayName,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: AppTypeScale.caption,
                    ),
                  ),
          ),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: _isFetchingMore
                ? const SizedBox(
                    width: AppSizes.iconSm,
                    height: AppSizes.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: () {
                      setState(() => _isFetchingMore = true);
                      _fetch();
                    },
                    child: Text(
                      'See more',
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: AppTypeScale.label,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
          ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
