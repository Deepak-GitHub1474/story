import 'package:flutter/widgets.dart';

class CommentGlyph extends StatelessWidget {
  const CommentGlyph({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _CommentPainter(color),
  );
}

class ShareGlyph extends StatelessWidget {
  const ShareGlyph({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SharePainter(color));
}

Paint _stroke(Color color, double scale) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.9 * scale
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

class _CommentPainter extends CustomPainter {
  const _CommentPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final bubble = RRect.fromLTRBR(
      2.6 * scale,
      2.6 * scale,
      21.4 * scale,
      17.4 * scale,
      Radius.circular(6.4 * scale),
    );

    final path = Path()
      ..addRRect(bubble)
      ..moveTo(7.6 * scale, 17.4 * scale)
      ..lineTo(6.2 * scale, 21.6 * scale)
      ..lineTo(12.4 * scale, 17.4 * scale);

    canvas.drawPath(path, _stroke(color, scale));
  }

  @override
  bool shouldRepaint(_CommentPainter old) => old.color != color;
}

class _SharePainter extends CustomPainter {
  const _SharePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;

    final plane = Path()
      ..moveTo(21.6 * scale, 2.6 * scale)
      ..lineTo(2.4 * scale, 10.2 * scale)
      ..lineTo(10.4 * scale, 13.6 * scale)
      ..lineTo(13.8 * scale, 21.4 * scale)
      ..close();

    final fold = Path()
      ..moveTo(10.4 * scale, 13.6 * scale)
      ..lineTo(21.6 * scale, 2.6 * scale);

    final ink = _stroke(color, scale);
    canvas.drawPath(plane, ink);
    canvas.drawPath(fold, ink);
  }

  @override
  bool shouldRepaint(_SharePainter old) => old.color != color;
}
