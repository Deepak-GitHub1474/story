import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/call_models.dart';
import '../providers/call_providers.dart';
import 'call_tile.dart';

class CallsTab extends ConsumerStatefulWidget {
  const CallsTab({required this.nameFor, super.key});

  final String Function(String peerId) nameFor;

  @override
  ConsumerState<CallsTab> createState() => _CallsTabState();
}

class _CallsTabState extends ConsumerState<CallsTab> {
  final Set<String> _selected = {};

  bool get _isSelecting => _selected.isNotEmpty;

  void _toggle(CallRecord record) {
    setState(() {
      if (!_selected.remove(record.callId)) _selected.add(record.callId);
    });
  }

  Future<void> _deleteSelected() async {
    final ids = _selected.toList();
    setState(_selected.clear);

    await ref.read(callRepositoryProvider).deleteMany(ids);
    ref.invalidate(callHistoryProvider);
  }

  Future<void> _callBack(CallRecord record) async {
    final problem = await ref
        .read(callControllerProvider.notifier)
        .place(record.conversationId);
    if (!mounted) return;

    if (problem != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    if (mounted) await context.push(Routes.call);
  }

  Future<void> _clearAll() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear call history?'),
        content: const Text(
          'Every call disappears from your list. Theirs is untouched, and this '
          'cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (sure != true) return;

    await ref.read(callRepositoryProvider).deleteAll();
    ref.invalidate(callHistoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final history = ref.watch(callHistoryProvider);

    return Column(
      children: [
        if (_isSelecting)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Text(
                  '${_selected.length} selected',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: AppTypeScale.label,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _deleteSelected,
                  child: Text('Delete', style: TextStyle(color: colors.danger)),
                ),
              ],
            ),
          ),
        Expanded(
          child: history.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _Empty(
              title: 'Could not load your calls',
              body: 'Check your connection and pull to refresh.',
            ),
            data: (records) {
              if (records.isEmpty) {
                return const _Empty(
                  title: 'No calls yet',
                  body: 'Calls you make and receive show up here, and only here.',
                );
              }

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(callHistoryProvider),
                child: ListView.builder(
                  itemCount: records.length + 1,
                  itemBuilder: (context, index) {
                    if (index == records.length) {
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Center(
                          child: TextButton(
                            onPressed: _clearAll,
                            child: Text(
                              'Clear call history',
                              style: TextStyle(color: colors.textMuted),
                            ),
                          ),
                        ),
                      );
                    }

                    final record = records[index];
                    return CallTile(
                      record: record,
                      name: widget.nameFor(record.peerId),
                      isSelected: _selected.contains(record.callId),
                      isSelecting: _isSelecting,
                      onTap: () {
                        if (_isSelecting) _toggle(record);
                      },
                      onLongPress: () => _toggle(record),
                      onCall: () => _callBack(record),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.call_outlined, size: 40, color: colors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: AppTypeScale.title,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: AppTypeScale.label,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
