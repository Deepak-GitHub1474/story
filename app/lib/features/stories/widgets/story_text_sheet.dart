import 'package:flutter/material.dart';

import '../../../components/app_sheet.dart';

Future<void> showStoryTextSheet(
  BuildContext context, {
  required String title,
  required TextSpan text,
}) => showAppSheet<void>(
  context: context,
  title: title,
  isResizable: true,
  initialSize: 0.75,
  minSize: 0.4,
  builder: (sheetContext) => RichText(text: text),
);
