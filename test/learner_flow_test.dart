import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillshift/app.dart';
import 'package:skillshift/core/auth/app_session.dart';
import 'package:skillshift/core/auth/session_controller.dart';
import 'package:skillshift/core/utils/time.dart';
import 'package:skillshift/data/models.dart';
import 'package:skillshift/features/learner/book_session_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await _settle(tester);
}

void main() {
  testWidgets('learner: quiz → matches → profile → free trial request', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: SkillShiftApp()));
    await _settle(tester);
    ProviderScope.containerOf(tester.element(find.byType(SkillShiftApp)))
        .read(sessionProvider.notifier)
        .startPreview(UserRole.learner);
    await _settle(tester);

    // L08 Home with sample data.
    expect(find.text('Hi, Nadia'), findsOneWidget);
    expect(find.text('Stuck on a course?'), findsOneWidget);

    // L09 empty state → L07 quiz.
    await _tap(tester, find.text('Find'));
    expect(find.text('Tell us what you need'), findsOneWidget);
    await _tap(tester, find.text('Start'));
    expect(find.text('A few quick questions'), findsOneWidget);
    await _tap(tester, find.text('Kalkulus 1'));
    await _tap(tester, find.text('Find my mentors'));

    // L09 results.
    expect(find.text('Top 3 mentors'), findsOneWidget);
    expect(find.text('Raka Pratama'), findsOneWidget);
    expect(find.text('Salsabila Hanum'), findsOneWidget);

    // L10 profile → L11 booking with Salsabila (trial available).
    await _tap(tester, find.text('Salsabila Hanum'));
    expect(find.text('WHY THIS MATCH'), findsOneWidget);
    await _tap(tester, find.text('Book a session'));
    expect(find.text('Book with Salsabila'), findsOneWidget);
    await _tap(tester, find.text('Review booking'));
    expect(find.text('Send a free trial request?'), findsOneWidget);
    await _tap(tester, find.text('Send request'));

    // Sessions tab shows the new request.
    expect(find.text('Kalkulus 1 with Salsabila'), findsOneWidget);
    expect(find.text('Requested'), findsOneWidget);
  });

  testWidgets('learner: free trial with Raka is already used', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: SkillShiftApp()));
    await _settle(tester);
    ProviderScope.containerOf(tester.element(find.byType(SkillShiftApp)))
        .read(sessionProvider.notifier)
        .startPreview(UserRole.learner);
    await _settle(tester);

    await _tap(tester, find.text('Find a mentor'));
    await _tap(tester, find.text('Kalkulus 1'));
    await _tap(tester, find.text('Find my mentors'));
    await _tap(tester, find.text('Raka Pratama'));
    await _tap(tester, find.text('Book a session'));

    expect(find.textContaining('Used on'), findsOneWidget);
    // Paid is preselected, so the action goes to checkout.
    expect(find.text('Review and pay'), findsOneWidget);
  });

  group('slotStarts', () {
    DateTime at(int d, String hhmm) => Wib.fromWall(
      DateTime.utc(2026, 11, d).add(Duration(minutes: parseHm(hhmm))),
    );

    test('30-minute steps inside a gap; 60 min must fit', () {
      final gaps = [Slot(at(24, '12:00'), at(24, '13:00'))];
      final day = DateTime.utc(2026, 11, 24);
      final for30 = slotStarts(gaps, day, 30);
      expect(for30.map((s) => fmtTime(s.start)), ['12:00', '12:30']);
      expect(for30.every((s) => s.fits), isTrue);

      final for60 = slotStarts(gaps, day, 60);
      expect(for60.map((s) => s.fits), [true, false]);
    });

    test('rounds odd gap starts up to :00 or :30, other days ignored', () {
      final gaps = [
        Slot(at(24, '09:10'), at(24, '10:20')),
        Slot(at(26, '09:30'), at(26, '10:20')),
      ];
      final starts = slotStarts(gaps, DateTime.utc(2026, 11, 24), 30);
      expect(starts.map((s) => fmtTime(s.start)), ['09:30']);
    });
  });
}
