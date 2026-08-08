import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_button.dart';
import '../../../components/app_sheet.dart';
import '../../../components/app_toast.dart';
import '../../../core/files/file_picker.dart';
import '../../../core/result.dart';
import '../../../routing/routes.dart';
import '../../vault/data/file_kind.dart';
import '../data/image_shape.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../../communities/providers/community_providers.dart';
import '../models/story_models.dart';
import '../providers/story_providers.dart';
import '../widgets/polish_sheet.dart';
import '../widgets/story_images.dart';

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
  final _images = <String>[];
  bool _isUploading = false;
  double? _imageRatio;
  String _imageFit = 'cover';
  bool _canFit = false;

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
      _images
        ..clear()
        ..addAll(story.images);
      _imageRatio = story.imageRatio;
      _imageFit = story.imageFit;
      _canFit = story.images.isNotEmpty;
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
        ? await repository.create(
            title: _titleOrNull,
            body: _body.text,
            images: _images,
            imageRatio: _imageRatio,
            imageFit: _imageFit,
          )
        : await repository.update(
            _storyId!,
            title: _title.text,
            body: _body.text,
            images: _images,
            imageRatio: _imageRatio,
            imageFit: _imageFit,
          );

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

  Future<void> _addImage() async {
    final file = await FilePicking.pick();
    if (file == null || !mounted) return;

    final kind = imageMimeOf(file.bytes, file.name);
    if (kind == null) {
      AppToast.show(
        context,
        'Pictures can be JPEG or PNG.',
        kind: AppToastKind.error,
      );
      return;
    }

    setState(() => _isUploading = true);
    final result = await ref
        .read(storyRepositoryProvider)
        .uploadImage(kind: kind, base64Data: base64Encode(file.bytes));

    if (!mounted) return;
    setState(() => _isUploading = false);

    final measured = await decodeImageFromList(file.bytes);
    if (!mounted) return;

    result.fold(
      onSuccess: (success) {
        setState(() {
          _images.add(success.value);
          _isDirty = true;
          if (_images.length == 1) {
            _imageRatio = postRatioFor(measured.width, measured.height);
            _canFit = isCropped(measured.width, measured.height);
            if (!_canFit) _imageFit = 'cover';
          }
        });
        unawaited(_save());
      },
      onFailure: (failure) =>
          AppToast.show(context, failure.message, kind: AppToastKind.error),
    );
  }

  Future<void> _polish() async {
    final polished = await showAppSheet<String>(
      context: context,
      title: 'Another go at it',
      builder: (sheetContext) => PolishSheet(text: _body.text),
    );

    if (polished == null || !mounted) return;
    setState(() => _body.text = polished);
    AppToast.show(context, 'Swapped in. Yours is one undo away.');
  }

  Future<void> _publish(String visibility, {bool exposureAck = false}) async {
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
      exposureAck: exposureAck,
    );

    if (!mounted) return;
    setState(() => _isPublishing = false);

    if (result.isSuccess) {
      final outcome = result.valueOrNull!;
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

      if (outcome.needsCare || outcome.suggestedCommunity != null) {
        await showAppSheet<void>(
          context: context,
          title: outcome.needsCare ? 'Before you go' : 'One more room',
          builder: (sheetContext) => _AfterPublishSheet(
            needsCare: outcome.needsCare,
            suggestedCommunity: outcome.suggestedCommunity,
          ),
        );
      }

      if (!mounted) return;
      context.pop();
    } else {
      await _handlePublishFailure(result.failureOrNull!, visibility);
    }
  }

  Future<void> _handlePublishFailure(
    Failure<PublishOutcome> failure,
    String visibility,
  ) async {
    if (failure.code == 'EXPOSURE_ACK_REQUIRED') {
      final goAhead = await showAppSheet<bool>(
        context: context,
        title: 'This could point back to you',
        builder: (sheetContext) =>
            _ExposureSheet(exposes: failure.exposes, message: failure.message),
      );
      if (goAhead == true && mounted) {
        await _publish(visibility, exposureAck: true);
      }
      return;
    }

    if (failure.code == 'MODERATION_BLOCKED') {
      await showAppSheet<void>(
        context: context,
        title: 'This cannot go up',
        builder: (sheetContext) => _BlockedSheet(
          reason: failure.message,
          rule: failure.details['rule'] as String?,
        ),
      );
      return;
    }

    if (!mounted) return;
    AppToast.show(context, failure.message, kind: AppToastKind.error);
  }

  Future<void> _openPublishSheet() async {
    final colors = context.colors;
    final choice = await showAppSheet<String>(
      context: context,
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
          IconButton(
            tooltip: 'Add a picture',
            icon: _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.image_outlined, color: colors.textPrimary),
            onPressed: _isUploading ? null : _addImage,
          ),
          IconButton(
            tooltip: 'Ask for a tidier version',
            icon: Icon(Icons.auto_awesome_outlined, color: colors.textPrimary),
            onPressed: _body.text.trim().isEmpty ? null : _polish,
          ),
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
                            if (_images.isNotEmpty) ...[
                              StoryImages(
                                images: _images,
                                ratio: _imageRatio,
                                fit: _imageFit,
                                onRemove: (path) {
                                  setState(() {
                                    _images.remove(path);
                                    if (_images.isEmpty) {
                                      _imageRatio = null;
                                      _imageFit = 'cover';
                                      _canFit = false;
                                    }
                                  });
                                  unawaited(_save());
                                },
                              ),
                              if (_canFit) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _FitToggle(
                                    isFitting: _imageFit == 'contain',
                                    onTap: () {
                                      setState(
                                        () => _imageFit =
                                            _imageFit == 'contain' ? 'cover' : 'contain',
                                      );
                                      unawaited(_save());
                                    },
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.md),
                            ],
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
            final choice = await showAppSheet<String?>(
      context: context,
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

class _ExposureSheet extends StatelessWidget {
  const _ExposureSheet({required this.exposes, required this.message});

  final List<String> exposes;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nobody here knows who you are, and we would like to keep it that '
            'way. These parts could give you away to someone who already knows '
            'you.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: AppTypeScale.label,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final item in exposes)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.remove_red_eye_outlined,
                    size: AppSizes.iconSm,
                    color: colors.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: AppTypeScale.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'It is your story. Go back and change it, or put it up as it is.',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: AppTypeScale.caption,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Let me edit it',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Publish it anyway',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}

class _BlockedSheet extends StatelessWidget {
  const _BlockedSheet({required this.reason, this.rule});

  final String reason;
  final String? rule;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reason,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: AppTypeScale.body,
              height: 1.6,
            ),
          ),
          if (rule != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                rule!.replaceAll('-', ' '),
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: AppTypeScale.caption,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Hard, dark and painful writing is welcome here. Only these five '
            'things are not, and each one is about somebody else getting hurt. '
            'Your draft is saved.',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: AppTypeScale.caption,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Back to the draft',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _AfterPublishSheet extends StatelessWidget {
  const _AfterPublishSheet({
    required this.needsCare,
    required this.suggestedCommunity,
  });

  final bool needsCare;
  final String? suggestedCommunity;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (needsCare) ...[
            Text(
              'It sounds like a heavy night. Your story is up and nobody has '
              'touched a word of it.',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: AppTypeScale.body,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'If you want to talk to somebody tonight, there are people who '
              'answer at any hour. Nobody here will know you looked.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: AppTypeScale.label,
                height: 1.55,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Line(label: 'India', number: 'Tele-MANAS 14416'),
            _Line(label: 'UK and Ireland', number: 'Samaritans 116 123'),
            _Line(label: 'US and Canada', number: 'Call or text 988'),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (suggestedCommunity != null) ...[
            Text(
              needsCare
                  ? 'There is also a room for this.'
                  : 'This might land better in another room.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: AppTypeScale.label,
                height: 1.55,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Open ${suggestedCommunity!.replaceAll('-', ' ')}',
              variant: AppButtonVariant.secondary,
              onPressed: () {
                Navigator.of(context).pop();
                context.push('${Routes.community}/$suggestedCommunity');
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppButton(
            label: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.number});

  final String label;
  final String number;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: AppTypeScale.label,
              ),
            ),
          ),
          Text(
            number,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: AppTypeScale.label,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FitToggle extends StatelessWidget {
  const _FitToggle({required this.isFitting, required this.onTap});

  final bool isFitting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: isFitting ? colors.accent : colors.border),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFitting ? Icons.fullscreen_exit : Icons.fullscreen,
              size: AppSizes.iconSm,
              color: isFitting ? colors.accent : colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              isFitting ? 'Whole picture' : 'Fill the frame',
              style: TextStyle(
                color: isFitting ? colors.accent : colors.textSecondary,
                fontSize: AppTypeScale.caption,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
