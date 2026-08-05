import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_toast.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../../communities/providers/community_providers.dart';
import '../models/story_models.dart';
import '../providers/story_providers.dart';

class ComposerScreen extends ConsumerStatefulWidget {
  const ComposerScreen({super.key, this.storyId});

  final String? storyId;

  @override
  ConsumerState<ComposerScreen> createState() => _ComposerScreenState();
}

class _ComposerScreenState extends ConsumerState<ComposerScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _bodyFocus = FocusNode();

  Timer? _autosave;
  String? _storyId;
  String? _communitySlug;
  bool _isLoading = false;
  bool _isPublishing = false;
  bool _isDirty = false;
  String _savedLabel = '';

  static const _bodyMax = 20000;

  @override
  void initState() {
    super.initState();
    _storyId = widget.storyId;
    if (_storyId != null) {
      _load();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bodyFocus.requestFocus());
    }
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await ref.read(storyRepositoryProvider).byId(_storyId!);
    if (!mounted) return;
    final story = result.valueOrNull;
    if (story != null) {
      _title.text = story.title ?? '';
      _body.text = story.body ?? '';
    }
    setState(() => _isLoading = false);
  }

  void _onChanged() {
    setState(() {
      _isDirty = true;
      _savedLabel = '';
    });
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 1200), _save);
  }

  Future<Story?> _save() async {
    if (_body.text.trim().isEmpty) return null;

    final repository = ref.read(storyRepositoryProvider);
    final result = _storyId == null
        ? await repository.create(title: _titleOrNull, body: _body.text)
        : await repository.update(_storyId!, title: _title.text, body: _body.text);

    if (!mounted) return null;

    final story = result.valueOrNull;
    if (story != null) {
      setState(() {
        _storyId = story.storyId;
        _isDirty = false;
        _savedLabel = 'Draft saved';
      });
      unawaited(ref.read(myStoriesProvider.notifier).refresh());
    } else {
      AppToast.show(context, result.failureOrNull!.message, kind: AppToastKind.error);
    }
    return story;
  }

  String? get _titleOrNull => _title.text.trim().isEmpty ? null : _title.text.trim();

  Future<DateTime?> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _publish(String visibility) async {
    DateTime? scheduledFor;
    if (visibility == 'scheduled') {
      scheduledFor = await _pickSchedule();
      if (scheduledFor == null) return;
    }

    setState(() => _isPublishing = true);
    _autosave?.cancel();

    final saved = await _save();
    final storyId = saved?.storyId ?? _storyId;
    if (storyId == null) {
      if (mounted) setState(() => _isPublishing = false);
      return;
    }

    final result = await ref.read(storyRepositoryProvider).publish(
      storyId,
      visibility: visibility,
      communitySlug: _communitySlug,
      scheduledFor: scheduledFor,
    );

    if (!mounted) return;
    setState(() => _isPublishing = false);

    if (result.isSuccess) {
      unawaited(ref.read(feedProvider.notifier).refresh());
      unawaited(ref.read(myStoriesProvider.notifier).refresh());
      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return;
      AppToast.show(
        context,
        switch (visibility) {
          'public' => 'Your story is live.',
          'scheduled' => 'Scheduled. It publishes on its own.',
          _ => 'Saved as private.',
        },
        kind: AppToastKind.success,
      );
      context.pop();
    } else {
      AppToast.show(context, result.failureOrNull!.message, kind: AppToastKind.error);
    }
  }

  Future<void> _openPublishSheet() async {
    final colors = context.colors;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Who can read this?',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: AppTypeScale.heading,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _VisibilityOption(
                icon: Icons.public,
                title: 'Public',
                subtitle: _communitySlug == null
                    ? 'Anyone on STORY can read it. Your real name is never attached.'
                    : 'Posts into the community you picked.',
                onTap: () => Navigator.of(sheetContext).pop('public'),
              ),
              const SizedBox(height: AppSpacing.md),
              _VisibilityOption(
                icon: Icons.lock_outline,
                title: 'Private',
                subtitle: 'Only you. Nobody else can open it, not even by link.',
                onTap: () => Navigator.of(sheetContext).pop('private'),
              ),
              const SizedBox(height: AppSpacing.md),
              _VisibilityOption(
                icon: Icons.schedule,
                title: 'Schedule',
                subtitle: 'Pick a time. It publishes itself, even if you are offline.',
                onTap: () => Navigator.of(sheetContext).pop('scheduled'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice != null) await _publish(choice);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canPublish = _body.text.trim().length >= 20;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            if (_isDirty) await _save();
            if (context.mounted) context.pop();
          },
        ),
        title: Text(
          _savedLabel.isEmpty ? 'Write' : _savedLabel,
          style: TextStyle(
            color: _savedLabel.isEmpty ? colors.textPrimary : colors.textMuted,
            fontSize: _savedLabel.isEmpty ? AppTypeScale.heading : AppTypeScale.label,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: canPublish && !_isPublishing ? _openPublishSheet : null,
            child: Text(
              'Publish',
              style: TextStyle(
                color: canPublish ? colors.accent : colors.textMuted,
                fontSize: AppTypeScale.body,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppSizes.maxContentWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _title,
                              onChanged: (_) => _onChanged(),
                              maxLength: 120,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: AppTypeScale.title,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Title, if you want one',
                                hintStyle: TextStyle(color: colors.textMuted),
                                border: InputBorder.none,
                                counterText: '',
                              ),
                            ),
                            Divider(color: colors.border, height: 1),
                            const SizedBox(height: AppSpacing.md),
                            _CommunityPicker(
                              slug: _communitySlug,
                              onPick: (slug) =>
                                  setState(() => _communitySlug = slug),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextField(
                              controller: _body,
                              focusNode: _bodyFocus,
                              onChanged: (_) => _onChanged(),
                              maxLines: null,
                              minLines: 12,
                              maxLength: _bodyMax,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: AppTypeScale.reading,
                                height: 1.7,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Say it here. Nobody knows who you are.',
                                hintStyle: TextStyle(color: colors.textMuted, height: 1.7),
                                border: InputBorder.none,
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxxl),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: colors.border)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${_body.text.trim().isEmpty ? 0 : _body.text.trim().split(RegExp(r'\s+')).length} words',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: AppTypeScale.caption,
                          ),
                        ),
                        const Spacer(),
                        if (_isPublishing)
                          const SizedBox(
                            width: AppSizes.iconSm,
                            height: AppSizes.iconSm,
                            child: CircularProgressIndicator(strokeWidth: 2),
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

class _VisibilityOption extends StatelessWidget {
  const _VisibilityOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.accent, size: AppSizes.iconMd),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: AppTypeScale.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: AppTypeScale.caption,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _CommunityPicker extends ConsumerWidget {
  const _CommunityPicker({required this.slug, required this.onPick});

  final String? slug;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final mine = ref.watch(myCommunitiesProvider);

    return mine.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final picked = items.where((item) => item.slug == slug).firstOrNull;

        return InkWell(
          onTap: () async {
            final choice = await showModalBottomSheet<String?>(
              context: context,
              backgroundColor: colors.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
              ),
              builder: (sheetContext) => SafeArea(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: Icon(Icons.public, color: colors.textMuted),
                      title: Text(
                        'No community',
                        style: TextStyle(color: colors.textPrimary),
                      ),
                      onTap: () => Navigator.of(sheetContext).pop(null),
                    ),
                    for (final community in items)
                      ListTile(
                        leading: Icon(Icons.groups_outlined, color: colors.accent),
                        title: Text(
                          community.name,
                          style: TextStyle(color: colors.textPrimary),
                        ),
                        onTap: () => Navigator.of(sheetContext).pop(community.slug),
                      ),
                  ],
                ),
              ),
            );
            onPick(choice);
          },
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  picked == null ? Icons.public : Icons.groups_outlined,
                  size: AppSizes.iconSm,
                  color: picked == null ? colors.textMuted : colors.accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  picked?.name ?? 'No community',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: AppTypeScale.caption,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: AppSizes.iconSm,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
