import '../result.dart';

String clockLabel(Duration left) {
  if (left <= Duration.zero) return '0:00';
  final minutes = left.inMinutes;
  final seconds = (left.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String resendLabel(Duration left) =>
    left <= Duration.zero ? 'Send it again' : 'Send again in ${left.inSeconds}s';

String waitLabel(Duration left) {
  if (left.inMinutes >= 2) return 'about ${left.inMinutes} minutes';
  if (left.inMinutes == 1) return 'about a minute';
  return '${left.inSeconds} seconds';
}

String otpTrouble(Failure<Object?> failure) {
  final left = failure.details['attempts_remaining'] as int?;
  final wait = failure.details['retry_after_seconds'] as int?;

  if (failure.code == 'OTP_LOCKED' || failure.code == 'RATE_LIMITED') {
    if (wait == null) return 'Too many tries. Come back a little later.';
    return 'Too many tries. Come back in ${waitLabel(Duration(seconds: wait))}.';
  }
  if (left == null) return failure.message;
  if (left == 1) return 'That code is not right. One try left.';
  return 'That code is not right. $left tries left.';
}
