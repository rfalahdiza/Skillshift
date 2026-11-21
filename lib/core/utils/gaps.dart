/// Free-gap calculation for one day, in minutes since midnight.
/// Mirrors `supabase/functions/_shared/gaps.ts` (the matching source of
/// truth); this copy drives the timetable and home screens.
library;

class TimeRange {
  const TimeRange(this.start, this.end) : assert(end >= start);

  final int start;
  final int end;

  int get minutes => end - start;

  bool contains(int minute) => minute >= start && minute < end;
  bool overlaps(TimeRange o) => start < o.end && o.start < end;

  @override
  bool operator ==(Object other) =>
      other is TimeRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'TimeRange($start-$end)';
}

/// Campus day used for matching: 07:00 to 17:00.
const kDayStart = 7 * 60;
const kDayEnd = 17 * 60;
const kMinGapMinutes = 30;

/// Gaps of at least [minMinutes] inside [windowStart, windowEnd) that are
/// not covered by any [busy] range. Busy ranges may overlap or extend past
/// the window.
List<TimeRange> freeGaps(
  Iterable<TimeRange> busy, {
  int windowStart = kDayStart,
  int windowEnd = kDayEnd,
  int minMinutes = kMinGapMinutes,
}) {
  final clipped =
      busy
          .where((r) => r.end > windowStart && r.start < windowEnd)
          .map(
            (r) => TimeRange(
              r.start < windowStart ? windowStart : r.start,
              r.end > windowEnd ? windowEnd : r.end,
            ),
          )
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  final gaps = <TimeRange>[];
  var cursor = windowStart;
  for (final r in clipped) {
    if (r.start > cursor) gaps.add(TimeRange(cursor, r.start));
    if (r.end > cursor) cursor = r.end;
  }
  if (cursor < windowEnd) gaps.add(TimeRange(cursor, windowEnd));
  return gaps.where((g) => g.minutes >= minMinutes).toList();
}

/// Gaps between classes only (not before the first or after the last class).
/// Used for "Free gap · 50 min" rows on the timetable.
List<TimeRange> gapsBetweenClasses(
  Iterable<TimeRange> classes, {
  int minMinutes = kMinGapMinutes,
}) {
  final sorted = classes.toList()..sort((a, b) => a.start.compareTo(b.start));
  if (sorted.length < 2) return const [];
  final first = sorted.first.start;
  final last = sorted.map((c) => c.end).reduce((a, b) => a > b ? a : b);
  return freeGaps(
    sorted,
    windowStart: first,
    windowEnd: last,
    minMinutes: minMinutes,
  );
}
