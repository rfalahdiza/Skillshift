import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/gaps.dart';
import '../../core/utils/time.dart';
import '../../data/models.dart';

/// T03: Monday–Friday grid, 07:00–17:00 WIB, with classes, free gaps and
/// booked sessions for one week.
class WeekGrid extends StatelessWidget {
  const WeekGrid({
    super.key,
    required this.entries,
    required this.bookings,
    required this.weekStart,
    this.onTapEntry,
  });

  final List<TimetableEntry> entries;
  final List<Booking> bookings;

  /// WIB wall-clock Monday 00:00 of the week shown.
  final DateTime weekStart;
  final ValueChanged<TimetableEntry>? onTapEntry;

  static const _hourHeight = 60.0;
  static const _timeColumn = 56.0;
  static const _firstHour = 7;
  static const _lastHour = 17;

  double _y(int minutes) => (minutes - _firstHour * 60) / 60 * _hourHeight;

  @override
  Widget build(BuildContext context) {
    final today = Wib.dateOnly(Wib.now());
    final height = (_lastHour - _firstHour) * _hourHeight;

    return Column(
      children: [
        // Day headers.
        Row(
          children: [
            const SizedBox(width: _timeColumn),
            for (var d = 0; d < 5; d++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _DayHeader(
                    label:
                        '${weekdayShort[d]} ${weekStart.add(Duration(days: d)).day}',
                    isToday: weekStart.add(Duration(days: d)) == today,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.md),
        SizedBox(
          height: height + 8,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hour labels.
              SizedBox(
                width: _timeColumn,
                child: Stack(
                  children: [
                    for (var h = _firstHour; h < _lastHour; h++)
                      Positioned(
                        top: _y(h * 60),
                        child: Text(
                          hm(h * 60),
                          style: AppText.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              for (var d = 1; d <= 5; d++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _dayColumn(d, height),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dayColumn(int weekday, double height) {
    final day = entries.where((e) => e.dayOfWeek == weekday).toList();
    final date = weekStart.add(Duration(days: weekday - 1));
    final booked = [
      for (final b in bookings)
        if ((b.status == BookingStatus.accepted ||
                b.status == BookingStatus.requested ||
                b.status == BookingStatus.completed) &&
            Wib.dateOnly(Wib.toWall(b.startsAt)) == date)
          b,
    ];
    TimeRange rangeOf(Booking b) {
      final s = Wib.toWall(b.startsAt);
      final e = Wib.toWall(b.endsAt);
      return TimeRange(s.hour * 60 + s.minute, e.hour * 60 + e.minute);
    }

    final bookedRanges = booked.map(rangeOf).toList();
    // Free gaps between classes, minus booked time.
    final gaps =
        freeGaps(
          [...day.map((e) => e.range), ...bookedRanges],
          windowStart: _firstHour * 60,
          windowEnd: _lastHour * 60,
        ).where(
          (g) =>
              day.any((e) => e.end <= g.start) &&
              day.any((e) => e.start >= g.end),
        );

    Positioned block(TimeRange r, Widget child) => Positioned(
      top: _y(r.start) + 1,
      left: 0,
      right: 0,
      height: (r.minutes / 60 * _hourHeight - 3).clamp(18, double.infinity),
      child: child,
    );

    return Stack(
      children: [
        // Hour lines.
        for (var h = _firstHour; h <= _lastHour; h++)
          Positioned(
            top: _y(h * 60),
            left: 0,
            right: 0,
            child: const Divider(height: 1),
          ),
        for (final e in day)
          block(
            e.range,
            _Block(
              color: AppColors.subtle,
              bar: AppColors.primary,
              title: e.courseName,
              subtitle: '${hm(e.start)}${e.room == null ? '' : ' · ${e.room}'}',
              onTap: onTapEntry == null ? null : () => onTapEntry!(e),
            ),
          ),
        for (final g in gaps)
          block(
            g,
            _Block(
              color: AppColors.primarySoft,
              dashed: true,
              title: 'Free · ${g.minutes} min',
              titleColor: AppColors.primaryPressed,
            ),
          ),
        for (final b in booked)
          block(
            rangeOf(b),
            _Block(
              color: AppColors.primary,
              title:
                  '${b.courseName} · '
                  '${(b.counterpartName ?? '').split(' ').first}',
              subtitle:
                  '${fmtTime(b.startsAt)} · '
                  '${b.status == BookingStatus.requested ? 'requested' : 'booked'}',
              titleColor: Colors.white,
              subtitleColor: Colors.white70,
            ),
          ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.isToday});

  final String label;
  final bool isToday;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      color: isToday ? AppColors.primarySoft : Colors.transparent,
      borderRadius: Radii.rSm,
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: AppText.smallSemibold.copyWith(
        color: isToday ? AppColors.primaryPressed : AppColors.textPrimary,
      ),
    ),
  );
}

class _Block extends StatelessWidget {
  const _Block({
    required this.color,
    required this.title,
    this.subtitle,
    this.bar,
    this.dashed = false,
    this.titleColor = AppColors.textPrimary,
    this.subtitleColor = AppColors.textTertiary,
    this.onTap,
  });

  final Color color;
  final String title;
  final String? subtitle;
  final Color? bar;
  final bool dashed;
  final Color titleColor;
  final Color subtitleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Short blocks (30-50 min) only have room for one line.
    final body = LayoutBuilder(
      builder: (context, c) => _content(c.maxHeight >= 56),
    );
    if (dashed) {
      return AppCardLite(color: color, child: body);
    }
    return Material(
      color: color,
      borderRadius: Radii.rSm,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: body),
    );
  }

  Widget _content(bool roomy) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bar != null) ...[
            Container(
              width: 3,
              height: 28,
              decoration: BoxDecoration(color: bar, borderRadius: Radii.rFull),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: ClipRect(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: roomy ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null && roomy)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        color: subtitleColor,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed teal box without the full AppCard padding.
class AppCardLite extends StatelessWidget {
  const AppCardLite({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _Dashed(),
    child: Container(
      decoration: BoxDecoration(color: color, borderRadius: Radii.rSm),
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );
}

class _Dashed extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          const Radius.circular(Radii.sm),
        ),
      );
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_Dashed old) => false;
}
