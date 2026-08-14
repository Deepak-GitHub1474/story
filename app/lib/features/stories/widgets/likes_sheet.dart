import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_avatar.dart';
import '../../../components/app_sheet.dart';
import '../../../components/app_text_field.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../communities/providers/community_providers.dart';
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
  shell: (sheetContext, scrollController) =>
      LikesSheet(storyId: storyId, scrollController: scrollController),
);

List<Liker> likersMatching(List<Liker> people, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return people;

  return people
      .where(
        (liker) =>
            liker.person.handle.toLowerCase().contains(needle) ||
            liker.person.displayName.toLowerCase().contains(needle),
      )
      .toList();
}

class LikesSheet extends ConsumerStatefulWidget {
  const LikesSheet({super.key, required this.storyId, this.scrollController});

  final String storyId;
  final ScrollController? scrollController;

  @override
  ConsumerState<LikesSheet> createState() => _LikesSheetState();
}

class _LikesSheetState extends ConsumerState<LikesSheet> {
  final _people = <Liker>[];
  final _search = TextEditingController();
  String? _cursor;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isFetchingMore = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _fetch();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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

  Future<void> _toggleFollow(Liker liker) async {
    final next = !liker.isFollowing;
    setState(() {
      final at = _people.indexWhere(
        (other) => other.person.userId == liker.person.userId,
      );
      if (at >= 0) _people[at] = liker.copyWith(isFollowing: next);
    });

    final result = await ref
        .read(communityRepositoryProvider)
        .setFollow(liker.person.handle, follow: next);

    if (!mounted || result.isSuccess) return;
    setState(() {
      final at = _people.indexWhere(
        (other) => other.person.userId == liker.person.userId,
      );
      if (at >= 0) _people[at] = liker;
    });
  }

  List<Liker> get _shown => likersMatching(_people, _search.text);

  void _openProfile(StoryAuthor person) {
    if (!person.isReachable) return;
    Navigator.of(context).pop();
    context.push('${Routes.user}/${person.username}');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppSheet(
      title: 'Likes',
      scrollController: widget.scrollController,
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
              child: Center(child: CircularProgressIndicator()),
            )
          : ListView(
              controller: widget.scrollController,
              padding: AppSheet.insets,
              children: [
                if (_people.length > 4 || _search.text.isNotEmpty) ...[
                  AppTextField(
                    controller: _search,
                    label: 'Search',
                    hint: 'Find someone who liked this',
                    prefixIcon: Icons.search,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxl,
                    ),
                    child: Center(
                      child: Text(
                        _failure ??
                            (_people.isEmpty
                                ? 'Nobody has liked this yet.'
                                : 'Nobody here by that name.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: AppTypeScale.label,
                        ),
                      ),
                    ),
                  ),
                for (final liker in _shown)
                  _LikerRow(
                    liker: liker,
                    onTap: () => _openProfile(liker.person),
                    onFollow: () => _toggleFollow(liker),
                  ),
                if (_hasMore && _search.text.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: Center(
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
                  ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
    );
  }
}

class _LikerRow extends StatelessWidget {
  const _LikerRow({
    required this.liker,
    required this.onTap,
    required this.onFollow,
  });

  final Liker liker;
  final VoidCallback onTap;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTap,
            child: AppAvatar(
              seed: liker.person.avatarSeed,
              size: 40,
              displayName: liker.person.displayName,
              username: liker.person.username,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    liker.person.handle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: AppTypeScale.label,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    liker.person.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: AppTypeScale.caption,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!liker.isMe) ...[
            const SizedBox(width: AppSpacing.md),
            _FollowButton(isFollowing: liker.isFollowing, onTap: onFollow),
          ],
        ],
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.isFollowing, required this.onTap});

  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isFollowing ? Colors.transparent : colors.accent,
          border: Border.all(
            color: isFollowing ? colors.border : colors.accent,
            width: AppSizes.hairline,
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: TextStyle(
            color: isFollowing ? colors.textPrimary : colors.accentText,
            fontSize: AppTypeScale.caption,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
