import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_avatar.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../data/call_session.dart';
import '../models/call_models.dart';
import '../providers/call_providers.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  Timer? _tick;
  Timer? _leaving;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _leaving?.cancel();
    super.dispose();
  }

  void _leaveWhenOver(CallSession session) {
    if (!session.isOver || _leaving != null) return;
    _leaving = Timer(const Duration(milliseconds: 1400), () {
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
  }

  String _status(CallSession session) => switch (session.phase) {
    CallPhase.idle => '',
    CallPhase.dialling => 'Calling…',
    CallPhase.ringing => 'Ringing…',
    CallPhase.connecting => 'Connecting…',
    CallPhase.connected => _elapsed(session),
    CallPhase.ended => switch (session.endReason) {
      'declined' => 'Declined',
      'timeout' => 'No answer',
      'offline' => 'Unavailable',
      _ => 'Call ended',
    },
  };

  String _elapsed(CallSession session) {
    final since = session.connectedAt;
    if (since == null) return '00:00';
    final seconds = DateTime.now().difference(since).inSeconds;
    final minutes = seconds ~/ 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final session = ref.watch(callControllerProvider);

    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    _leaveWhenOver(session);

    final peer = session.peer;
    final isIncoming = session.isIncoming && session.phase == CallPhase.ringing;
    final isLive = session.phase == CallPhase.connected ||
        session.phase == CallPhase.connecting;
    final controller = ref.read(callControllerProvider.notifier);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              AppAvatar(
                seed: peer?.avatarSeed ?? peer?.userId ?? '',
                size: 128,
                displayName: peer?.displayName,
                username: peer?.username,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                peer?.displayName ?? 'Someone',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: AppTypeScale.title,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _status(session),
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: AppTypeScale.body,
                ),
              ),
              if (session.phase == CallPhase.connected) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
              const Spacer(),
              if (isLive)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Round(
                      icon: session.isMuted ? Icons.mic_off : Icons.mic,
                      label: session.isMuted ? 'Unmute' : 'Mute',
                      isOn: session.isMuted,
                      onTap: controller.toggleMute,
                    ),
                    _Round(
                      icon: session.isSpeakerOn ? Icons.volume_up : Icons.hearing,
                      label: 'Speaker',
                      isOn: session.isSpeakerOn,
                      onTap: controller.toggleSpeaker,
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.xl),
              if (session.isOver)
                const SizedBox(height: 72)
              else if (isIncoming)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Big(
                      icon: Icons.call_end,
                      color: colors.danger,
                      onTap: controller.decline,
                    ),
                    _Big(
                      icon: Icons.call,
                      color: colors.success,
                      onTap: () async {
                        final problem = await controller.accept();
                        if (problem != null && context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(problem)));
                        }
                      },
                    ),
                  ],
                )
              else
                _Big(
                  icon: Icons.call_end,
                  color: colors.danger,
                  onTap: controller.hangUp,
                ),
            ],
          ),
        ),
      ),
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
  const _Big({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    customBorder: const CircleBorder(),
    child: Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: Icon(icon, color: Colors.white, size: 30),
    ),
  );
}
