import 'dart:io';

import 'package:flutter/services.dart';

class CallUi {
  const CallUi._();

  static const _channel = MethodChannel('story/call_ui');

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

  static Future<void> stopRinging() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stopRinging');
    } on PlatformException {
      return;
    }
  }

  static Future<void> startOngoing(String peer) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('startOngoing', {'peer': peer});
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
