import 'dart:math';

import 'package:flutter/material.dart';

const faceCount = 10;

enum HairStyle { bobFringe, longPart, bunTop, longFringe, bunLow, quiff, crop, sidePart, curls, afro }

class FaceStyle {
  const FaceStyle({
    required this.skin,
    required this.shadow,
    required this.hair,
    required this.backdrop,
    required this.style,
  });

  final Color skin;
  final Color shadow;
  final Color hair;
  final Color backdrop;
  final HairStyle style;

  bool get isLongHair => style.index < HairStyle.quiff.index;

  bool get hasBun => style == HairStyle.bunTop || style == HairStyle.bunLow;

  bool get hasFringe => style == HairStyle.bobFringe || style == HairStyle.longFringe;
}

const _porcelain = Color(0xFFF6D9C6);
const _light = Color(0xFFEBBC97);
const _olive = Color(0xFFC98D62);
const _brown = Color(0xFF9A5F35);
const _deep = Color(0xFF5E3720);

const _porcelainShade = Color(0xFFE2BBA4);
const _lightShade = Color(0xFFD29B74);
const _oliveShade = Color(0xFFAB7049);
const _brownShade = Color(0xFF7C4826);
const _deepShade = Color(0xFF442513);

const faceStyles = <FaceStyle>[
  FaceStyle(
    skin: _porcelain,
    shadow: _porcelainShade,
    hair: Color(0xFF3A2A22),
    backdrop: Color(0xFFFFE1EC),
    style: HairStyle.bobFringe,
  ),
  FaceStyle(
    skin: _light,
    shadow: _lightShade,
    hair: Color(0xFFC9762F),
    backdrop: Color(0xFFFFE9D2),
    style: HairStyle.longPart,
  ),
  FaceStyle(
    skin: _olive,
    shadow: _oliveShade,
    hair: Color(0xFF1E1712),
    backdrop: Color(0xFFDDEBFF),
    style: HairStyle.bunTop,
  ),
  FaceStyle(
    skin: _brown,
    shadow: _brownShade,
    hair: Color(0xFF241813),
    backdrop: Color(0xFFE4E0FF),
    style: HairStyle.longFringe,
  ),
  FaceStyle(
    skin: _deep,
    shadow: _deepShade,
    hair: Color(0xFF15100D),
    backdrop: Color(0xFFD8F2E4),
    style: HairStyle.bunLow,
  ),
  FaceStyle(
    skin: _porcelain,
    shadow: _porcelainShade,
    hair: Color(0xFFB98A4C),
    backdrop: Color(0xFFD9F0FF),
    style: HairStyle.quiff,
  ),
  FaceStyle(
    skin: _light,
    shadow: _lightShade,
    hair: Color(0xFF2C2119),
    backdrop: Color(0xFFE7E4DC),
    style: HairStyle.crop,
  ),
  FaceStyle(
    skin: _olive,
    shadow: _oliveShade,
    hair: Color(0xFF19120E),
    backdrop: Color(0xFFFFE3D5),
    style: HairStyle.sidePart,
  ),
  FaceStyle(
    skin: _brown,
    shadow: _brownShade,
    hair: Color(0xFF120D0A),
    backdrop: Color(0xFFDCE8FF),
    style: HairStyle.curls,
  ),
  FaceStyle(
    skin: _deep,
    shadow: _deepShade,
    hair: Color(0xFF0F0B09),
    backdrop: Color(0xFFFFE7BF),
    style: HairStyle.afro,
  ),
];

int faceIndexFor(String seed) {
  if (seed.isEmpty) return 0;
  final hash = seed.codeUnits.fold<int>(7, (acc, unit) => (acc * 31 + unit) & 0x7fffffff);
  return hash % faceCount;
}

class AvatarFacePainter extends CustomPainter {
  const AvatarFacePainter(this.style);

  final FaceStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final brush = Paint()..isAntiAlias = true;

    brush.color = style.backdrop;
    canvas.drawCircle(Offset(s / 2, s / 2), s / 2, brush);

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, s, s)));

    brush.color = style.shadow;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.295, s * 0.835, s * 0.41, s * 0.28),
        Radius.circular(s * 0.18),
      ),
      brush,
    );

    if (style.isLongHair) {
      brush.color = style.hair;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.175, s * 0.16, s * 0.65, s * 0.72),
          Radius.circular(s * 0.32),
        ),
        brush,
      );
    }

    if (style.style == HairStyle.afro) {
      brush.color = style.hair;
      canvas.drawCircle(Offset(s / 2, s * 0.375), s * 0.295, brush);
    }

    if (style.hasBun) {
      brush.color = style.hair;
      final y = style.style == HairStyle.bunTop ? s * 0.145 : s * 0.215;
      canvas.drawCircle(Offset(s * 0.335, y), s * 0.072, brush);
      canvas.drawCircle(Offset(s * 0.665, y), s * 0.072, brush);
    }

    brush.color = style.skin;
    canvas.drawCircle(Offset(s * 0.245, s * 0.545), s * 0.052, brush);
    canvas.drawCircle(Offset(s * 0.755, s * 0.545), s * 0.052, brush);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.255, s * 0.245, s * 0.49, s * 0.52),
        Radius.circular(s * 0.245),
      ),
      brush,
    );

    brush.color = style.hair;
    switch (style.style) {
      case HairStyle.bobFringe:
      case HairStyle.longFringe:
        canvas.drawPath(_bob(s), brush);
      case HairStyle.longPart:
      case HairStyle.bunTop:
      case HairStyle.bunLow:
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.25, s * 0.47)
            ..lineTo(s * 0.25, s * 0.40)
            ..quadraticBezierTo(s * 0.50, s * 0.155, s * 0.75, s * 0.40)
            ..lineTo(s * 0.75, s * 0.47)
            ..quadraticBezierTo(s * 0.70, s * 0.33, s * 0.545, s * 0.335)
            ..quadraticBezierTo(s * 0.36, s * 0.345, s * 0.25, s * 0.47)
            ..close(),
          brush,
        );
      case HairStyle.crop:
        canvas.drawPath(_crop(s), brush);
      case HairStyle.quiff:
        canvas.drawPath(_crop(s), brush);
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.34, s * 0.255)
            ..quadraticBezierTo(s * 0.44, s * 0.095, s * 0.70, s * 0.185)
            ..quadraticBezierTo(s * 0.54, s * 0.195, s * 0.47, s * 0.30)
            ..close(),
          brush,
        );
      case HairStyle.sidePart:
        canvas.drawPath(_crop(s), brush);
        brush.color = style.skin;
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.615, s * 0.205)
            ..quadraticBezierTo(s * 0.665, s * 0.265, s * 0.675, s * 0.345)
            ..quadraticBezierTo(s * 0.625, s * 0.275, s * 0.575, s * 0.235)
            ..close(),
          brush,
        );
      case HairStyle.curls:
        canvas.drawPath(_crop(s), brush);
        for (final spot in [
          [0.305, 0.325],
          [0.375, 0.245],
          [0.465, 0.212],
          [0.560, 0.228],
          [0.645, 0.290],
          [0.695, 0.365],
        ]) {
          canvas.drawCircle(Offset(s * spot[0], s * spot[1]), s * 0.062, brush);
        }
      case HairStyle.afro:
        canvas.drawPath(_crop(s), brush);
    }

    brush.color = const Color(0xFFF08A9B).withValues(alpha: 0.42);
    canvas.drawOval(Rect.fromLTWH(s * 0.285, s * 0.565, s * 0.105, s * 0.062), brush);
    canvas.drawOval(Rect.fromLTWH(s * 0.610, s * 0.565, s * 0.105, s * 0.062), brush);

    brush.color = const Color(0xFF3A2B26);
    canvas.drawOval(Rect.fromLTWH(s * 0.348, s * 0.470, s * 0.098, s * 0.118), brush);
    canvas.drawOval(Rect.fromLTWH(s * 0.554, s * 0.470, s * 0.098, s * 0.118), brush);

    brush.color = Colors.white;
    canvas.drawCircle(Offset(s * 0.420, s * 0.502), s * 0.021, brush);
    canvas.drawCircle(Offset(s * 0.626, s * 0.502), s * 0.021, brush);
    canvas.drawCircle(Offset(s * 0.376, s * 0.556), s * 0.011, brush);
    canvas.drawCircle(Offset(s * 0.582, s * 0.556), s * 0.011, brush);

    brush.style = PaintingStyle.stroke;
    brush.strokeCap = StrokeCap.round;

    brush.color = const Color(0xFF6E4B3F);
    brush.strokeWidth = s * 0.030;
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.437, s * 0.655)
        ..quadraticBezierTo(s * 0.50, s * 0.712, s * 0.563, s * 0.655),
      brush,
    );

    canvas.restore();
  }

  Path _crop(double s) => Path()
    ..moveTo(s * 0.245, s * 0.455)
    ..quadraticBezierTo(s * 0.245, s * 0.175, s * 0.50, s * 0.175)
    ..quadraticBezierTo(s * 0.755, s * 0.175, s * 0.755, s * 0.455)
    ..quadraticBezierTo(s * 0.70, s * 0.335, s * 0.50, s * 0.335)
    ..quadraticBezierTo(s * 0.30, s * 0.335, s * 0.245, s * 0.455)
    ..close();

  Path _bob(double s) => Path()
    ..moveTo(s * 0.235, s * 0.52)
    ..lineTo(s * 0.235, s * 0.38)
    ..quadraticBezierTo(s * 0.50, s * 0.145, s * 0.765, s * 0.38)
    ..lineTo(s * 0.765, s * 0.52)
    ..quadraticBezierTo(s * 0.735, s * 0.36, s * 0.50, s * 0.365)
    ..quadraticBezierTo(s * 0.265, s * 0.36, s * 0.235, s * 0.52)
    ..close();

  @override
  bool shouldRepaint(AvatarFacePainter oldDelegate) => oldDelegate.style != style;
}

class AvatarFace extends StatelessWidget {
  const AvatarFace({super.key, required this.seed, required this.size});

  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = faceStyles[min(faceIndexFor(seed), faceStyles.length - 1)];
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: AvatarFacePainter(style)),
    );
  }
}
