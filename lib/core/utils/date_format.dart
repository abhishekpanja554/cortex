/// Human-friendly timestamps without pulling in `intl`.
class AppDateFormat {
  AppDateFormat._();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  static String time(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// "Just now", "Today, 8:26 PM", "Yesterday", "Monday", "12 Oct", "12 Oct 2025".
  static String relative(DateTime date, {DateTime? now}) {
    final local = date.toLocal();
    final current = (now ?? DateTime.now()).toLocal();
    final diff = current.difference(local);

    if (diff.inSeconds >= 0 && diff.inSeconds < 60) return 'Just now';

    final today = DateTime(current.year, current.month, current.day);
    final day = DateTime(local.year, local.month, local.day);
    final dayDiff = today.difference(day).inDays;

    if (dayDiff == 0) return 'Today, ${time(local)}';
    if (dayDiff == 1) return 'Yesterday';
    if (dayDiff > 1 && dayDiff < 7) return _weekdays[local.weekday - 1];

    final base = '${local.day} ${_months[local.month - 1]}';
    return local.year == current.year ? base : '$base ${local.year}';
  }
}
