import 'package:flutter/widgets.dart';

class EnvelopeGlyph extends StatelessWidget {
  const EnvelopeGlyph({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _EnvelopePainter(color),
  );
}

class KeyholeGlyph extends StatelessWidget {
  const KeyholeGlyph({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _KeyholePainter(color));
}

Paint _stroke(Color color, double scale) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.9 * scale
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

class _EnvelopePainter extends CustomPainter {
  const _EnvelopePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final ink = _stroke(color, scale);

    final body = RRect.fromLTRBR(
      6.2 * scale,
      6.4 * scale,
      21.4 * scale,
      18.2 * scale,
      Radius.circular(2.6 * scale),
    );

    final flap = Path()
      ..moveTo(6.6 * scale, 7.6 * scale)
      ..lineTo(13.8 * scale, 13.2 * scale)
      ..lineTo(21.0 * scale, 7.6 * scale);

    final trail = Path()
      ..moveTo(1.2 * scale, 9.6 * scale)
      ..lineTo(4.4 * scale, 9.6 * scale)
      ..moveTo(2.4 * scale, 12.4 * scale)
      ..lineTo(4.4 * scale, 12.4 * scale)
      ..moveTo(0.8 * scale, 15.2 * scale)
      ..lineTo(4.4 * scale, 15.2 * scale);

    canvas.drawRRect(body, ink);
    canvas.drawPath(flap, ink);
    canvas.drawPath(trail, ink);
  }

  @override
  bool shouldRepaint(_EnvelopePainter old) => old.color != color;
}

class _KeyholePainter extends CustomPainter {
  const _KeyholePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final ink = _stroke(color, scale);

    final plate = RRect.fromLTRBR(
      4.6 * scale,
      2.8 * scale,
      19.4 * scale,
      21.2 * scale,
      Radius.circular(4.6 * scale),
    );

    final stem = Path()
      ..moveTo(12.0 * scale, 12.6 * scale)
      ..lineTo(10.9 * scale, 17.4 * scale)
      ..lineTo(13.1 * scale, 17.4 * scale)
      ..close();

    canvas.drawRRect(plate, ink);
    canvas.drawCircle(Offset(12 * scale, 9.8 * scale), 2.7 * scale, ink);
    canvas.drawPath(stem, ink);
  }

  @override
  bool shouldRepaint(_KeyholePainter old) => old.color != color;
}
