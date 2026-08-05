import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_button.dart';
import '../../../components/app_card.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/app_text_field.dart';
import '../../../components/app_toast.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/recovery_models.dart';
import '../providers/recovery_providers.dart';

const _stateLabels = {
  'submitted': 'Waiting for a person to pick it up',
  'under_review': 'A person is reviewing it',
  'needs_more_info': 'They need more from you',
  'reveal_ready': 'Approved. Your passcode is ready to collect.',
  'closed': 'Closed',
  'rejected': 'Rejected',
};

const _eventLabels = {
  'passcode_release.approved': 'A super admin released your passcode',
  'vault.passcodes_listed': 'A super admin saw your passcode names',
  'account.blocked': 'Your account was blocked',
  'account.unblocked': 'Your account was unblocked',
};

class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({super.key});

  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen> {
  final _reason = TextEditingController();
  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    final result = await ref
        .read(recoveryRepositoryProvider)
        .open(type: 'passcode_release', reason: _reason.text.trim());

    if (!mounted) return;
    setState(() => _isBusy = false);

    result.fold(
      onSuccess: (_) {
        _reason.clear();
        ref.invalidate(ticketsProvider);
        AppToast.show(context, 'Request opened.', kind: AppToastKind.success);
      },
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tickets = ref.watch(ticketsProvider);
    final activity = ref.watch(securityActivityProvider);

    return AppScaffold(
      title: 'Recovery',
      child: ListView(
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What we can and cannot do',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: AppTypeScale.body,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Forgot your account password? Nobody can recover it, and nothing '
                  'in your vault survives without it.\n\n'
                  'Forgot only your vault passcode? A super admin can release the '
                  'copy you sealed when you created it. It goes to you, never to '
                  'them, and you still need your password to open anything.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: AppTypeScale.label,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const AppSection(title: 'Your requests', children: []),
          tickets.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
            error: (_, _) => _Empty(text: 'Could not load your requests.'),
            data: (items) => items.isEmpty
                ? const _Empty(text: 'You have not asked for anything.')
                : Column(children: items.map(_TicketRow.new).toList()),
          ),
          if (tickets.valueOrNull?.any((t) => t.isOpen) != true) ...[
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _reason,
              label: 'Why do you need your passcode released?',
              hint: 'Say what happened, in your own words.',
              maxLines: 4,
              errorText: _error,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Ask for a passcode release',
              onPressed: _isBusy ? null : _open,
              isLoading: _isBusy,
            ),
          ],
          const AppSection(title: 'Who touched your account', children: []),
          activity.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
            error: (_, _) => const _Empty(text: 'Could not load activity.'),
            data: (items) => items.isEmpty
                ? const _Empty(text: 'No staff has touched your account.')
                : Column(children: items.map(_EventRow.new).toList()),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow(this.ticket);

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ticket.isReady ? Icons.key_outlined : Icons.hourglass_empty,
                  size: 18,
                  color: ticket.isReady ? colors.success : colors.textMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _stateLabels[ticket.state] ?? ticket.state,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: AppTypeScale.label,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ticket.reason,
              style: TextStyle(color: colors.textSecondary, fontSize: AppTypeScale.caption),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow(this.event);

  final SecurityEvent event;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      label: _eventLabels[event.action] ?? event.action,
      value: event.occurredAt.split('T').first,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Text(
        text,
        style: TextStyle(
          color: context.colors.textMuted,
          fontSize: AppTypeScale.label,
        ),
      ),
    );
  }
}
