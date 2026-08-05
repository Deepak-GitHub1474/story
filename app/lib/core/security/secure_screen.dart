import 'dart:io';

import 'package:flutter/services.dart';

class SecureScreen {
  const SecureScreen._();

  static const _channel = MethodChannel('story/secure_screen');

  static Future<void> enable() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('enable');
    } on PlatformException {
      return;
    }
  }

  static Future<void> disable() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('disable');
    } on PlatformException {
      return;
    }
  }
}
