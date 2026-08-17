import 'package:flutter/widgets.dart';

bool longerThanLines({
  required TextSpan span,
  required double width,
  required int lines,
  required TextDirection direction,
  TextScaler scaler = TextScaler.noScaling,
}) {
  if (width <= 0 || lines <= 0) return false;

  final painter = TextPainter(
    text: span,
    maxLines: lines,
    textDirection: direction,
    textScaler: scaler,
  )..layout(maxWidth: width);

  return painter.didExceedMaxLines;
}

double widthOf({
  required TextSpan span,
  required TextDirection direction,
  TextScaler scaler = TextScaler.noScaling,
}) {
  final painter = TextPainter(
    text: span,
    maxLines: 1,
    textDirection: direction,
    textScaler: scaler,
  )..layout();

  return painter.width;
}

bool tallerThan({
  required TextSpan span,
  required double width,
  required double cap,
  required TextDirection direction,
  TextScaler scaler = TextScaler.noScaling,
}) {
  if (width <= 0 || cap <= 0) return false;

  final painter = TextPainter(
    text: span,
    textDirection: direction,
    textScaler: scaler,
  )..layout(maxWidth: width);

  return painter.height > cap;
}
