import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../components/app_close_button.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

Future<void> showVaultPreview({
  required BuildContext context,
  required Future<Uint8List?> Function() open,
  Uint8List? ready,
}) => Navigator.of(context, rootNavigator: true).push(
  PageRouteBuilder<void>(
    opaque: false,
    transitionDuration: AppMotion.fast,
    pageBuilder: (context, animation, secondary) => FadeTransition(
      opacity: animation,
      child: _Preview(open: open, ready: ready),
    ),
  ),
);

class _Preview extends StatefulWidget {
  const _Preview({required this.open, this.ready});

  final Future<Uint8List?> Function() open;
  final Uint8List? ready;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _bytes = widget.ready;
    if (_bytes == null) _load();
  }

  Future<void> _load() async {
    final opened = await widget.open();
    if (!mounted) return;
    setState(() {
      _bytes = opened;
      _failed = opened == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: AppMotion.base,
                child: bytes != null
                    ? InteractiveViewer(
                        key: const ValueKey('image'),
                        minScale: 1,
                        maxScale: 4,
                        child: Center(
                          child: Image.memory(
                            bytes,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                            gaplessPlayback: true,
                          ),
                        ),
                      )
                    : _Waiting(key: const ValueKey('wait'), failed: _failed),
              ),
            ),
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: AppCloseButton(
                isOnImage: true,
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({super.key, required this.failed});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!failed)
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  strokeCap: StrokeCap.round,
                  color: colors.accent,
                ),
              )
            else
              Icon(Icons.lock_outline, color: colors.textMuted, size: 34),
            const SizedBox(height: AppSpacing.lg),
            Text(
              failed ? 'This one will not open' : 'Unlocking your file',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: AppTypeScale.body,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              failed
                  ? 'Close this and try again in a moment.'
                  : 'It is being decrypted on this phone. One moment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textMuted,
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
