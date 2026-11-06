import 'package:cortex/core/utils/date_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 22, 20, 30);

  test('under a minute is "Just now"', () {
    expect(AppDateFormat.relative(now.subtract(const Duration(seconds: 20)), now: now), 'Just now');
  });

  test('same day shows time', () {
    expect(AppDateFormat.relative(DateTime(2026, 10, 22, 8, 5), now: now), 'Today, 8:05 AM');
  });

  test('previous calendar day is "Yesterday"', () {
    expect(AppDateFormat.relative(DateTime(2026, 10, 21, 23, 59), now: now), 'Yesterday');
  });

  test('within a week shows weekday', () {
    // 19 Oct 2026 is a Monday.
    expect(AppDateFormat.relative(DateTime(2026, 10, 19, 9), now: now), 'Monday');
  });

  test('older dates show day and month, plus year when different', () {
    expect(AppDateFormat.relative(DateTime(2026, 3, 4), now: now), '4 Mar');
    expect(AppDateFormat.relative(DateTime(2025, 3, 4), now: now), '4 Mar 2025');
  });

  test('12-hour clock edge cases', () {
    expect(AppDateFormat.time(DateTime(2026, 1, 1, 0, 7)), '12:07 AM');
    expect(AppDateFormat.time(DateTime(2026, 1, 1, 12, 0)), '12:00 PM');
  });
}
