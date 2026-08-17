import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BloomMark extends StatelessWidget {
  const BloomMark({
    super.key,
    required this.width,
    required this.height,
    this.fit = BoxFit.contain,
  });

  final double width;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final grain = MediaQuery.devicePixelRatioOf(context);

    return IgnorePointer(
      child: Image.asset(
        context.colors.bloom,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        cacheWidth: (width * grain).round(),
        cacheHeight: (height * grain).round(),
      ),
    );
  }
}
