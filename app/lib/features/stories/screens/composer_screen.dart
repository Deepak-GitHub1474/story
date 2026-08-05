import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_toast.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
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

  Future<void> _publish(String visibility) async {
    setState(() => _isPublishing = true);
    _autosave?.cancel();

    final saved = await _save();
    final storyId = saved?.storyId ?? _storyId;
    if (storyId == null) {
      if (mounted) setState(() => _isPublishing = false);
      return;
    }

    final result = await ref
        .read(storyRepositoryProvider)
        .publish(storyId, visibility: visibility);

    if (!mounted) return;
    setState(() => _isPublishing = false);

    if (result.isSuccess) {
      unawaited(ref.read(feedProvider.notifier).refresh());
      unawaited(ref.read(myStoriesProvider.notifier).refresh());
      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return;
      AppToast.show(
        context,
        visibility == 'public' ? 'Your story is live.' : 'Saved as private.',
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
                subtitle: 'Anyone on STORY can read it. Your real name is never attached.',
                onTap: () => Navigator.of(sheetContext).pop('public'),
              ),
              const SizedBox(height: AppSpacing.md),
              _VisibilityOption(
                icon: Icons.lock_outline,
                title: 'Private',
                subtitle: 'Only you. Nobody else can open it, not even by link.',
                onTap: () => Navigator.of(sheetContext).pop('private'),
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
                            const SizedBox(height: AppSpacing.lg),
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
