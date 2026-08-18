import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/push/push_service.dart';
import 'package:story_app/core/result.dart';
import 'package:story_app/features/notifications/data/notification_repository.dart';

NotificationSettings settingsWith(AuthorizationStatus status) => NotificationSettings(
  alert: AppleNotificationSetting.enabled,
  announcement: AppleNotificationSetting.disabled,
  authorizationStatus: status,
  badge: AppleNotificationSetting.enabled,
  carPlay: AppleNotificationSetting.disabled,
  lockScreen: AppleNotificationSetting.enabled,
  notificationCenter: AppleNotificationSetting.enabled,
  showPreviews: AppleShowPreviewSetting.always,
  timeSensitive: AppleNotificationSetting.disabled,
  criticalAlert: AppleNotificationSetting.disabled,
  sound: AppleNotificationSetting.enabled,
  providesAppNotificationSettings: AppleNotificationSetting.disabled,
);

class FakeMessaging implements FirebaseMessaging {
  FakeMessaging({
    this.status = AuthorizationStatus.authorized,
    this.token = 'fcm-token-value',
  });

  final AuthorizationStatus status;
  final String? token;
  bool tokenDeleted = false;
  bool permissionAsked = false;

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async {
    permissionAsked = true;
    return settingsWith(status);
  }

  @override
  Future<String?> getToken({String? serviceWorkerScriptPath, String? vapidKey}) async =>
      token;

  @override
  Future<void> deleteToken() async {
    tokenDeleted = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingRepository implements NotificationRepository {
  final registered = <Map<String, String>>[];
  final forgotten = <String>[];

  RecordingRepository({this.answer = const Success(true)});

  final Result<bool> answer;

  @override
  Future<Result<bool>> registerPushToken({
    required String token,
    required String platform,
  }) async {
    registered.add({'token': token, 'platform': platform});
    return answer;
  }

  @override
  Future<Result<bool>> forgetPushToken(String token) async {
    forgotten.add(token);
    return const Success(true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('turning it on hands the phone token to the server', () async {
    final repository = RecordingRepository();
    final messaging = FakeMessaging();

    final problem = await PushService(repository, messaging).enable();

    expect(problem, isNull, reason: 'nothing went wrong, so nothing to report');
    expect(messaging.permissionAsked, isTrue);
    expect(repository.registered.single['token'], 'fcm-token-value');
    expect(repository.registered.single['platform'], devicePlatform);
  });

  test('a refused permission registers nothing at all', () async {
    final repository = RecordingRepository();
    final messaging = FakeMessaging(status: AuthorizationStatus.denied);

    final problem = await PushService(repository, messaging).enable();

    expect(problem, contains('phone settings'));
    expect(
      repository.registered,
      isEmpty,
      reason: 'a token the reader never agreed to must never reach the server',
    );
  });

  test('a phone that yields no token is not registered', () async {
    final repository = RecordingRepository();
    final messaging = FakeMessaging(token: null);

    final problem = await PushService(repository, messaging).enable();

    expect(problem, contains('token from Google'));
    expect(repository.registered, isEmpty);
  });

  test('a server that refuses says why, not "check your phone settings"', () async {
    final repository = RecordingRepository(
      answer: const Failure(code: 'NOT_FOUND', message: 'That route is gone.'),
    );

    final problem = await PushService(repository, FakeMessaging()).enable();

    expect(
      problem,
      'That route is gone.',
      reason: 'blaming the phone for a server fault sends people to the wrong screen',
    );
  });

  test('turning it off erases the token here and on the server', () async {
    final repository = RecordingRepository();
    final messaging = FakeMessaging();

    await PushService(repository, messaging).disable();

    expect(repository.forgotten.single, 'fcm-token-value');
    expect(
      messaging.tokenDeleted,
      isTrue,
      reason: 'leaving the token alive means the phone can still be reached',
    );
  });

  test('a rotated token is handed over without asking again', () async {
    final repository = RecordingRepository();
    final messaging = FakeMessaging();

    await PushService(repository, messaging).refreshRegistration();

    expect(repository.registered.single['token'], 'fcm-token-value');
    expect(
      messaging.permissionAsked,
      isFalse,
      reason: 'permission was already granted, so do not prompt on refresh',
    );
  });
}
