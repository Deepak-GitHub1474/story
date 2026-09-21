import 'dart:io';

import 'package:flutter/services.dart';

class CallUi {
  const CallUi._();

  static const _channel = MethodChannel('story/call_ui');

  static void onIntent(
    void Function(String callId, String? action) handler,
  ) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'incomingCall') return null;
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final callId = args['callId'];
      if (callId is String && callId.isNotEmpty) {
        handler(callId, args['action'] as String?);
      }
      return null;
    });
  }

  static Future<void> ring({
    required String callId,
    required String caller,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('ring', {
        'callId': callId,
        'caller': caller,
      });
    } on PlatformException {
      return;
    }
  }

  static Future<void> startRingback() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('startRingback');
    } on PlatformException {
      return;
    }
  }

  static Future<void> stopRingback() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stopRingback');
    } on PlatformException {
      return;
    }
  }

  static Future<void> hideRingNotification() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('hideRingNotification');
    } on PlatformException {
      return;
    }
  }

  static Future<void> stopRinging() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stopRinging');
    } on PlatformException {
      return;
    }
  }

  static Future<void> startOngoing(String peer, String callId) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('startOngoing', {
        'peer': peer,
        'callId': callId,
      });
    } on PlatformException {
      return;
    }
  }

  static Future<void> stopOngoing() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stopOngoing');
    } on PlatformException {
      return;
    }
  }

  static Future<String?> pendingCallId() async {
    if (!Platform.isAndroid) return null;
    try {
      final found = await _channel.invokeMapMethod<String, String?>('pendingCall');
      return found?['callId'];
    } on PlatformException {
      return null;
    }
  }

  static Future<void> volumeForRinging() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('volumeForRinging');
    } on PlatformException {
      return;
    }
  }

  static Future<void> volumeForCall() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('volumeForCall');
    } on PlatformException {
      return;
    }
  }

  static Future<void> startAudio() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('startAudio');
    } on PlatformException {
      return;
    }
  }

  static Future<void> stopAudio() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stopAudio');
    } on PlatformException {
      return;
    }
  }

  static Future<bool> setSpeaker(bool on) async {
    if (!Platform.isAndroid) return on;
    try {
      return await _channel.invokeMethod<bool>('setSpeaker', {'on': on}) ?? on;
    } on PlatformException {
      return on;
    }
  }

  static Future<bool> requestNotifications() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('requestNotifications') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> requestMicrophone() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('requestMicrophone') ?? false;
    } on PlatformException {
      return false;
    }
  }
}
