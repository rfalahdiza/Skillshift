import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillshift/app.dart';
import 'package:skillshift/core/auth/app_session.dart';
import 'package:skillshift/core/auth/session_controller.dart';
import 'package:skillshift/shared/widgets/app_button.dart';

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

Future<ProviderContainer> _start(
  WidgetTester tester,
  Size size,
  UserRole role,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: SkillShiftApp()));
  await _settle(tester);
  final c = ProviderScope.containerOf(
    tester.element(find.byType(SkillShiftApp)),
  );
  c.read(sessionProvider.notifier).startPreview(role);
  await _settle(tester);
  return c;
}

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<AppButton>(find.widgetWithText(AppButton, label)).onPressed !=
    null;

void main() {
  testWidgets('mentor edits teaching profile; switch to learner', (
    tester,
  ) async {
    final c = await _start(tester, const Size(390, 1100), UserRole.mentor);

    await _tap(tester, find.text('Profile'));
    expect(find.text('Teaching profile'), findsOneWidget);
    expect(find.textContaining('••••••'), findsOneWidget); // NIM masked
    expect(_enabled(tester, 'Save teaching profile'), isFalse);

    await _tap(tester, find.text('Concept first'));
    expect(_enabled(tester, 'Save teaching profile'), isTrue);
    await _tap(tester, find.text('Save teaching profile'));
    expect(find.text('Teaching profile saved.'), findsOneWidget);

    await _tap(tester, find.text('Switch to learner'));
    expect(c.read(sessionProvider).value?.role, UserRole.learner);
    expect(find.text('Hi, Raka'), findsOneWidget);
  });

  testWidgets('T03: tablet timetable shows the week grid', (tester) async {
    await _start(tester, const Size(1280, 800), UserRole.learner);

    await _tap(tester, find.text('Timetable'));
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Next week'), findsOneWidget);
    expect(find.textContaining('Mon '), findsWidgets);
    expect(find.textContaining('Fri '), findsWidgets);
    expect(find.text('Fisika Dasar'), findsWidgets);
    expect(find.textContaining('Free · '), findsWidgets);
  });

  testWidgets('T04: tablet booking pays from the right column', (tester) async {
    await _start(tester, const Size(1280, 900), UserRole.learner);

    await _tap(tester, find.text('Find mentors'));
    await _tap(tester, find.text('Start'));
    await _tap(tester, find.text('Kalkulus 1'));
    await _tap(tester, find.text('Find my mentors'));
    // Wide matches: profile is on the right; book Raka (trial used → paid).
    await _tap(tester, find.text('Book a session'));

    expect(find.text('Book with Raka'), findsOneWidget);
    expect(find.text('Sandbox · test payment'), findsOneWidget);
    expect(_enabled(tester, 'Pay Rp25.000'), isFalse);
    await _tap(tester, find.textContaining('graded work for me'));
    await _tap(tester, find.text('Pay Rp25.000'));
    expect(find.text('Complete payment'), findsOneWidget);
  });

  testWidgets('T06: tablet earnings table', (tester) async {
    await _start(tester, const Size(1280, 800), UserRole.mentor);

    await _tap(tester, find.text('Earnings'));
    expect(find.text('FEE (10%)'), findsOneWidget);
    expect(find.text('YOU GET'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Released'), findsWidgets);
    expect(find.text('Withdraw (simulated)'), findsOneWidget);
  });
}
