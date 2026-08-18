import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../../features/notifications/data/notification_repository.dart';

String get devicePlatform => Platform.isIOS ? 'ios' : 'android';

class PushService {
  const PushService(this._repository, this._messaging);

  final NotificationRepository _repository;
  final FirebaseMessaging _messaging;

  Future<String?> enable() async {
    final permission = await _messaging.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      return 'Allow notifications for Story in your phone settings first.';
    }

    final token = await _messaging.getToken();
    if (token == null) {
      return 'This phone could not get a notification token from Google.';
    }

    final result = await _repository.registerPushToken(
      token: token,
      platform: devicePlatform,
    );
    return result.fold(
      onSuccess: (_) => null,
      onFailure: (failure) => failure.message,
    );
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
