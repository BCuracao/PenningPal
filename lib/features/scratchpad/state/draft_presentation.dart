/// Relative timestamps for the drafts drawer (pure Dart, no Flutter).
String formatRelativeTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final localTime = time.toLocal();
  final localNow = current.toLocal();
  final diff = localNow.difference(localTime);

  if (diff.isNegative || diff.inSeconds < 15) return 'Just now';
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24 && _isSameDay(localTime, localNow)) {
    return '${diff.inHours}h ago';
  }

  final yesterday = DateTime(localNow.year, localNow.month, localNow.day)
      .subtract(const Duration(days: 1));
  if (_isSameDay(localTime, yesterday)) return 'Yesterday';

  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${localTime.year}-${_two(localTime.month)}-${_two(localTime.day)}';
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _two(int value) => value.toString().padLeft(2, '0');
