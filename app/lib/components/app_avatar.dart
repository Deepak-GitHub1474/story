import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.seed, this.size = 56});

  final String seed;
  final double size;

  static const _palette = [
    Color(0xFF9B8CFF),
    Color(0xFF7BD88F),
    Color(0xFFFFB86B),
    Color(0xFF6BC5FF),
    Color(0xFFFF8AB8),
    Color(0xFFE0C36B),
  ];

  @override
  Widget build(BuildContext context) {
    final hash = seed.codeUnits.fold<int>(7, (acc, unit) => (acc * 31 + unit) & 0x7fffffff);
    final base = _palette[hash % _palette.length];
    final accent = _palette[(hash ~/ 7) % _palette.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [base, accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: context.colors.border),
      ),
      alignment: Alignment.center,
      child: Text(
        String.fromCharCode(65 + (hash % 26)),
        style: TextStyle(
          color: const Color(0xFF0B0D12),
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
