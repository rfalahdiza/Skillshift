import 'package:intl/intl.dart';

/// Western Indonesia Time (UTC+7, no daylight saving). Campus times are
/// always shown in WIB, whatever the device time zone is.
///
/// A "wall" DateTime holds WIB clock fields in a UTC-flagged DateTime, so
/// arithmetic and formatting never touch the device zone.
abstract final class Wib {
  static const offset = Duration(hours: 7);

  /// Overridable clock for tests.
  static DateTime Function() clock = DateTime.now;

  static DateTime now() => toWall(clock());

  static DateTime toWall(DateTime instant) {
    final u = instant.toUtc().add(offset);
    return DateTime.utc(u.year, u.month, u.day, u.hour, u.minute, u.second);
  }

  /// WIB wall clock → real UTC instant (for storing in timestamptz).
  static DateTime fromWall(DateTime wall) => DateTime.utc(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
  ).subtract(offset);

  static DateTime dateOnly(DateTime wall) =>
      DateTime.utc(wall.year, wall.month, wall.day);
}

/// Minutes since midnight → "09:30".
String hm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

/// "09:30" or "09:30:00" → 570.
int parseHm(String value) {
  final parts = value.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const weekdayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// All formatters take an instant and show it in WIB.
String fmtTime(DateTime instant) =>
    DateFormat('HH:mm').format(Wib.toWall(instant));
String fmtDayShort(DateTime instant) =>
    DateFormat('EEE').format(Wib.toWall(instant)); // Tue
String fmtDayNum(DateTime instant) =>
    DateFormat('EEE d').format(Wib.toWall(instant)); // Tue 24
String fmtDate(DateTime instant) =>
    DateFormat('EEE, d MMM').format(Wib.toWall(instant)); // Tue, 24 Nov
String fmtDayMonth(DateTime instant) =>
    DateFormat('d MMM').format(Wib.toWall(instant)); // 18 Nov

/// "Tue 12:00 to 13:00".
String fmtSlot(DateTime start, DateTime end) =>
    '${fmtDayShort(start)} ${fmtTime(start)} to ${fmtTime(end)}';

/// "Good morning" / "Good afternoon" / "Good evening" in WIB.
String greeting([DateTime? wall]) {
  final h = (wall ?? Wib.now()).hour;
  if (h < 11) return 'Good morning';
  if (h < 15) return 'Good afternoon';
  return 'Good evening';
}
