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
