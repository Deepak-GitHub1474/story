import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../../features/notifications/data/notification_repository.dart';

String get devicePlatform => Platform.isIOS ? 'ios' : 'android';

class PushService {
  const PushService(this._repository, this._messaging);

  final NotificationRepository _repository;
  final FirebaseMessaging _messaging;

  Future<bool> enable() async {
    final permission = await _messaging.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      return false;
    }

    final token = await _messaging.getToken();
    if (token == null) return false;

    final result = await _repository.registerPushToken(
      token: token,
      platform: devicePlatform,
    );
    return result.valueOrNull ?? false;
  }

  Future<void> disable() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _repository.forgetPushToken(token);
    }
    await _messaging.deleteToken();
  }

  Future<void> refreshRegistration() async {
    final token = await _messaging.getToken();
    if (token == null) return;
    await _repository.registerPushToken(token: token, platform: devicePlatform);
  }

  Stream<String> get tokenChanges => _messaging.onTokenRefresh;
}
