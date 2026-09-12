import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_avatar.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../data/call_session.dart';
import '../models/call_models.dart';
import '../providers/call_providers.dart';

const List<String> quickReplies = [
  "I'm busy now. What's up?",
  "I'm on my way!",
  "Can't talk now, I'll call you back!",
];

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  Timer? _tick;
  Timer? _exit;
  bool _leaving = false;
  bool? _wasReceiver;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final session = ref.read(callControllerProvider);
      if (session?.phase == CallPhase.connected) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(callControllerProvider.notifier).silenceRing();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _exit?.cancel();
    super.dispose();
  }

  void _scheduleExit(CallSession session) {
    if (!session.isOver || _exit != null) return;

    final seconds = _lingerSeconds(session);
    if (seconds == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close();
      });
      return;
    }

    _exit = Timer(Duration(seconds: seconds), () {
      if (mounted) _close();
    });
  }

  int _lingerSeconds(CallSession session) {
    if (_wasReceiver ?? false) return 0;
    if (session.endedByMe) return 2;
    return 5;
  }

  String _status(CallSession session) => switch (session.phase) {
    CallPhase.idle => '',
    CallPhase.dialling => 'Calling…',
    CallPhase.ringing => session.isIncoming ? 'Incoming call' : 'Ringing…',
    CallPhase.connecting => 'Connecting…',
    CallPhase.connected => _elapsed(session),
    CallPhase.ended => _ending(session),
  };

  String _ending(CallSession session) {
    if (session.wasAnswered || session.endedByMe) return 'Call ended';
    return switch (session.endReason) {
      'declined' => "Didn't join",
      'timeout' => 'Not answered',
      'offline' => 'Unavailable',
      'busy' => 'On another call',
      _ => 'Call ended',
    };
  }

  String _elapsed(CallSession session) {
    final since = session.connectedAt;
    if (since == null) return '00:00';
    final seconds = DateTime.now().difference(since).inSeconds;
    final minutes = seconds ~/ 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }

  void _close() {
    if (_leaving) return;
    _leaving = true;
    ref.read(callControllerProvider.notifier).dismiss();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> _callAgain(CallSession session) async {
    final conversationId = session.start?.conversationId;
    if (conversationId == null || conversationId.isEmpty) return;

    final problem = await ref
        .read(callControllerProvider.notifier)
        .place(conversationId);

    if (problem != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(problem)));
    }
  }

  Future<void> _openReplies() async {
    final colors = context.colors;

    final chosen = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Reply with',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: AppTypeScale.heading,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final reply in quickReplies)
              ListTile(
                title: Text(
                  reply,
                  style: TextStyle(color: colors.textPrimary),
                ),
                onTap: () => Navigator.of(sheetContext).pop(reply),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );

    if (chosen == null || !mounted) return;
    await ref.read(callControllerProvider.notifier).replyAndDecline(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final session = ref.watch(callControllerProvider);

    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close();
      });
      return Scaffold(backgroundColor: colors.bg, body: const SizedBox.shrink());
    }

    _wasReceiver ??= session.isIncoming;
    _scheduleExit(session);

    final peer = session.peer;
    final isIncoming = session.isIncoming && session.phase == CallPhase.ringing;
    final hasControls =
        !session.isOver &&
        (session.phase == CallPhase.connected ||
            session.phase == CallPhase.connecting ||
            (!isIncoming && session.phase != CallPhase.idle));
    final controller = ref.read(callControllerProvider.notifier);

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: double.infinity, height: 0),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AppAvatar(
                      seed: peer?.avatarSeed ?? peer?.userId ?? '',
                      size: 128,
                      displayName: peer?.displayName,
                      username: peer?.username,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      peer?.displayName ?? 'Someone',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: AppTypeScale.title,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _status(session),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: AppTypeScale.body,
                      ),
                    ),
                    if (session.phase == CallPhase.connected) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, size: 14, color: colors.textMuted),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Encrypted end to end',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: AppTypeScale.caption,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (hasControls) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Round(
                            icon: session.isMuted ? Icons.mic_off : Icons.mic,
                            label: session.isMuted ? 'Unmute' : 'Mute',
                            isOn: session.isMuted,
                            onTap: controller.toggleMute,
                          ),
                          const SizedBox(width: AppSpacing.xl),
                          _Round(
                            icon: session.isSpeakerOn
                                ? Icons.volume_up
                                : Icons.hearing,
                            label: 'Speaker',
                            isOn: session.isSpeakerOn,
                            onTap: controller.toggleSpeaker,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    if (isIncoming) ...[
                      TextButton.icon(
                        onPressed: _openReplies,
                        icon: Icon(
                          Icons.chat_bubble_outline,
                          size: 18,
                          color: colors.textPrimary,
                        ),
                        label: Text(
                          'Reply',
                          style: TextStyle(color: colors.textPrimary),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    _Actions(
                      session: session,
                      isIncoming: isIncoming,
                      onDecline: controller.decline,
                      onHangUp: controller.hangUp,
                      onAnswer: () async {
                        final problem = await controller.accept();
                        if (problem != null && context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(problem)));
                        }
                      },
                      onCallAgain: () => _callAgain(session),
                      onClose: _close,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.session,
    required this.isIncoming,
    required this.onDecline,
    required this.onHangUp,
    required this.onAnswer,
    required this.onCallAgain,
    required this.onClose,
  });

  final CallSession session;
  final bool isIncoming;
  final VoidCallback onDecline;
  final VoidCallback onHangUp;
  final VoidCallback onAnswer;
  final VoidCallback onCallAgain;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (session.isOver) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Big(
            icon: Icons.close,
            label: 'Close',
            color: colors.surfaceRaised,
            iconColor: colors.textPrimary,
            onTap: onClose,
          ),
          const SizedBox(width: AppSpacing.xxl),
          _Big(
            icon: Icons.call,
            label: 'Call again',
            color: colors.accent,
            iconColor: colors.accentText,
            onTap: onCallAgain,
          ),
        ],
      );
    }

    if (isIncoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Big(
            icon: Icons.call_end,
            label: 'Decline',
            color: colors.danger,
            onTap: onDecline,
          ),
          const SizedBox(width: AppSpacing.xxl),
          _Big(
            icon: Icons.call,
            label: 'Answer',
            color: colors.success,
            onTap: onAnswer,
          ),
        ],
      );
    }

    return _Big(
      icon: Icons.call_end,
      label: 'End',
      color: colors.danger,
      onTap: onHangUp,
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({
    required this.icon,
    required this.label,
    required this.isOn,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOn ? colors.accent : colors.surfaceRaised,
            ),
            child: Icon(
              icon,
              color: isOn ? colors.accentText : colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: AppTypeScale.caption,
          ),
        ),
      ],
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, color: iconColor, size: 30),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: AppTypeScale.caption,
          ),
        ),
      ],
    );
  }
}
