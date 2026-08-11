const _months = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

DateTime? localOf(String? isoUtc) {
  if (isoUtc == null || isoUtc.isEmpty) return null;
  return DateTime.tryParse(isoUtc)?.toLocal();
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String clockOf(DateTime local) {
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
}

String messageClock(String? isoUtc) {
  final local = localOf(isoUtc);
  return local == null ? '' : clockOf(local);
}

String daySeparator(DateTime local, {DateTime? now}) {
  final today = now?.toLocal() ?? DateTime.now();
  final midnight = DateTime(today.year, today.month, today.day);
  final that = DateTime(local.year, local.month, local.day);
  final days = midnight.difference(that).inDays;

  if (days == 0) return 'TODAY';
  if (days == 1) return 'YESTERDAY';

  final day = local.day.toString().padLeft(2, '0');
  final month = _months[local.month - 1];

  if (days < 7) return '${_weekdays[local.weekday - 1]} $day $month';
  if (local.year == today.year) return '$day $month';
  return '$day $month ${local.year}';
}

String separatorFor(String? isoUtc, {DateTime? now}) {
  final local = localOf(isoUtc);
  return local == null ? '' : daySeparator(local, now: now);
}

bool startsNewDay(String? isoUtc, String? previousIsoUtc) {
  final current = localOf(isoUtc);
  if (current == null) return false;

  final previous = localOf(previousIsoUtc);
  if (previous == null) return true;

  return !isSameDay(current, previous);
}
