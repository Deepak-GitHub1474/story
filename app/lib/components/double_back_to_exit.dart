import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_toast.dart';

class DoubleBackToExit extends StatefulWidget {
  const DoubleBackToExit({super.key, required this.child, this.onBack});

  final Widget child;
  final bool Function()? onBack;

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

  void _handleBack() {
    if (widget.onBack?.call() ?? false) {
      _lastPress = null;
      return;
    }

    if (_withinWindow) {
      SystemNavigator.pop();
      return;
    }

    _lastPress = DateTime.now();
    AppToast.show(context, 'Press back again to leave.');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: widget.child,
    );
  }
}
