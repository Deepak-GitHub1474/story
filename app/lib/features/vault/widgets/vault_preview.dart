import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../components/app_close_button.dart';
import '../../../theme/tokens.dart';

Future<void> showVaultPreview({
  required BuildContext context,
  required Uint8List bytes,
}) => Navigator.of(context, rootNavigator: true).push(
  PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black,
    transitionDuration: AppMotion.base,
    pageBuilder: (context, animation, secondary) => FadeTransition(
      opacity: animation,
      child: _Preview(bytes: bytes),
    ),
  ),
);

class _Preview extends StatelessWidget {
  const _Preview({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stack) => const Text(
                      'This file cannot be shown.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
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
