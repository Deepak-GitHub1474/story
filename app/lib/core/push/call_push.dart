import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../security/call_ui.dart';

const String callKind = 'call';
const String callCancelledKind = 'call_cancelled';

bool isCallPush(Map<String, dynamic> data) =>
    data['kind'] == callKind || data['kind'] == callCancelledKind;

Future<void> ringFrom(Map<String, dynamic> data) async {
  if (data['kind'] == callCancelledKind) {
    await CallUi.stopRinging();
    return;
  }

  if (data['kind'] != callKind) return;

  final callId = data['call_id'];
  if (callId is! String || callId.isEmpty) return;

  await CallUi.ring(
    callId: callId,
    caller: data['caller_name'] as String? ?? 'Someone',
  );
}

@pragma('vm:entry-point')
Future<void> onBackgroundCall(RemoteMessage message) async {
  await Firebase.initializeApp();
  await ringFrom(Map<String, dynamic>.from(message.data));
}
