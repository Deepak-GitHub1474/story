String timeAgo(String? isoUtc) {
  if (isoUtc == null || isoUtc.isEmpty) return '';
  final parsed = DateTime.tryParse(isoUtc);
  if (parsed == null) return '';

  final difference = DateTime.now().toUtc().difference(parsed.toUtc());
  if (difference.inSeconds < 60) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m';
  if (difference.inHours < 24) return '${difference.inHours}h';
  if (difference.inDays < 7) return '${difference.inDays}d';
  if (difference.inDays < 365) return '${(difference.inDays / 7).floor()}w';
  return '${(difference.inDays / 365).floor()}y';
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _plural(int value, String unit) =>
    '$value $unit${value == 1 ? '' : 's'} ago';

String timeAgoLong(String? isoUtc) {
  if (isoUtc == null || isoUtc.isEmpty) return '';
  final parsed = DateTime.tryParse(isoUtc);
  if (parsed == null) return '';

  final difference = DateTime.now().toUtc().difference(parsed.toUtc());
  if (difference.inSeconds < 60) return 'just now';
  if (difference.inMinutes < 60) return _plural(difference.inMinutes, 'min');
  if (difference.inHours < 24) return _plural(difference.inHours, 'hour');
  if (difference.inDays <= 7) return _plural(difference.inDays, 'day');

  final local = parsed.toUtc().toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}
