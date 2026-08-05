import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_toast.dart';

class DoubleBackToExit extends StatefulWidget {
  const DoubleBackToExit({super.key, required this.child});

  final Widget child;

  static const window = Duration(seconds: 2);

  @override
  State<DoubleBackToExit> createState() => _DoubleBackToExitState();
}

class _DoubleBackToExitState extends State<DoubleBackToExit> {
  DateTime? _lastPress;

  bool get _withinWindow {
    final last = _lastPress;
    return last != null && DateTime.now().difference(last) < DoubleBackToExit.window;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_withinWindow) {
          SystemNavigator.pop();
          return;
        }

        _lastPress = DateTime.now();
        AppToast.show(context, 'Press back again to leave.');
      },
      child: widget.child,
    );
  }
}
