import 'package:flutter/material.dart';

import '../core/identity/handle.dart';

Widget? handleLine({
  required String displayName,
  required String username,
  required TextStyle style,
}) {
  final handle = handleFor(displayName: displayName, username: username);
  return handle == null ? null : Text(handle, style: style);
}
