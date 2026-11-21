import 'package:flutter_test/flutter_test.dart';
import 'package:skillshift/core/utils/gaps.dart';
import 'package:skillshift/core/utils/time.dart';

TimeRange r(String a, String b) => TimeRange(parseHm(a), parseHm(b));

void main() {
  group('freeGaps', () {
    test('empty day is one 07:00-17:00 gap', () {
      expect(freeGaps(const []), [r('07:00', '17:00')]);
    });

    test("Nadia's Tuesday from the L06 design", () {
      final classes = [
        r('07:00', '09:30'),
        r('10:20', '12:00'),
        r('13:00', '15:30'),
      ];
      expect(freeGaps(classes), [
        r('09:30', '10:20'), // 50 min
        r('12:00', '13:00'), // 60 min
        r('15:30', '17:00'),
      ]);
    });

    test('merges overlapping and unsorted busy ranges', () {
      final busy = [
        r('10:00', '11:00'),
        r('08:00', '09:00'),
        r('08:30', '10:15'),
      ];
      expect(freeGaps(busy), [r('07:00', '08:00'), r('11:00', '17:00')]);
    });

    test('drops gaps shorter than 30 minutes, keeps exactly 30', () {
      final busy = [
        r('07:00', '09:00'),
        r('09:20', '12:00'),
        r('12:30', '17:00'),
      ];
      expect(freeGaps(busy), [r('12:00', '12:30')]);
    });

    test('clips busy ranges outside the window', () {
      final busy = [r('06:00', '08:00'), r('16:30', '19:00')];
      expect(freeGaps(busy), [r('08:00', '16:30')]);
    });

    test('fully booked day has no gaps', () {
      expect(freeGaps([r('06:00', '18:00')]), isEmpty);
    });

    test('custom minimum', () {
      final busy = [r('07:00', '09:00'), r('09:45', '17:00')];
      expect(freeGaps(busy, minMinutes: 60), isEmpty);
      expect(freeGaps(busy, minMinutes: 45), [r('09:00', '09:45')]);
    });
  });

  test('gapsBetweenClasses ignores time before and after classes', () {
    final classes = [
      r('07:00', '09:30'),
      r('10:20', '12:00'),
      r('13:00', '15:30'),
    ];
    expect(gapsBetweenClasses(classes), [
      r('09:30', '10:20'),
      r('12:00', '13:00'),
    ]);
    expect(gapsBetweenClasses([r('07:00', '09:30')]), isEmpty);
  });

  group('Wib', () {
    test('converts wall clock both ways', () {
      final instant = DateTime.utc(2026, 11, 24, 5, 0); // 12:00 WIB
      final wall = Wib.toWall(instant);
      expect((wall.hour, wall.minute, wall.day), (12, 0, 24));
      expect(Wib.fromWall(wall), instant);
    });

    test('formats in WIB regardless of instant zone', () {
      final instant = DateTime.utc(2026, 11, 24, 5, 0);
      expect(fmtTime(instant), '12:00');
      expect(fmtDate(instant), 'Tue, 24 Nov');
      expect(
        fmtSlot(instant, instant.add(const Duration(hours: 1))),
        'Tue 12:00 to 13:00',
      );
    });

    test('hm and parseHm', () {
      expect(hm(570), '09:30');
      expect(parseHm('09:30:00'), 570);
    });
  });
}
