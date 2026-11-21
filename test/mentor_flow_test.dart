import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillshift/app.dart';
import 'package:skillshift/core/auth/app_session.dart';
import 'package:skillshift/core/auth/session_controller.dart';

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

Future<void> _startAsMentor(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: SkillShiftApp()));
  await _settle(tester);
  ProviderScope.containerOf(tester.element(find.byType(SkillShiftApp)))
      .read(sessionProvider.notifier)
      .startPreview(UserRole.mentor);
  await _settle(tester);
}

void main() {
  testWidgets('mentor home: only paid/held or free-trial requests; accept', (
    tester,
  ) async {
    await _startAsMentor(tester);

    expect(find.text('Hi, Raka'), findsOneWidget);
    expect(find.textContaining('Verified mentor'), findsOneWidget);
    expect(find.text('Simulated'), findsOneWidget);

    // Nadia paid (held) → shown. Dewi has not paid → hidden.
    expect(find.text('Nadia Putri'), findsOneWidget);
    expect(find.text('Dewi Anggraini'), findsNothing);
    expect(find.textContaining('Wants: worked examples'), findsOneWidget);

    await _tap(tester, find.text('Accept'));
    expect(find.textContaining('Accepted.'), findsOneWidget);
    expect(
      find.text(
        'No new requests. Learners see you when they share a '
        'free gap with you.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('mentor confirms attendance for a session in progress', (
    tester,
  ) async {
    await _startAsMentor(tester);

    await _tap(tester, find.text('Now'));
    expect(find.text('Session'), findsOneWidget);
    expect(find.textContaining('you receive Rp22.500'), findsOneWidget);
    await _tap(tester, find.text('Confirm attendance'));
    expect(find.text('Waiting for Bagas'), findsOneWidget);
  });

  testWidgets('earnings are labelled simulated', (tester) async {
    await _startAsMentor(tester);

    await _tap(tester, find.text('Earnings'));
    expect(
      find.textContaining('Payouts are simulated in this prototype'),
      findsOneWidget,
    );
    // Available: 2 released × Rp22.500; on hold: 2 held × Rp22.500.
    expect(find.text('Rp45.000'), findsNWidgets(2));
    expect(find.text('Platform fee 10%'), findsOneWidget);
    await _tap(tester, find.text('Withdraw (simulated)'));
    expect(find.textContaining('no bank transfer is made'), findsOneWidget);
  });

  testWidgets('apply for another course: M01 → M02 → M03', (tester) async {
    await _startAsMentor(tester);

    // The card is below the fold in a lazily built list: scroll to it.
    await tester.scrollUntilVisible(
      find.text('Add another course'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await _tap(tester, find.text('Add another course'));
    expect(find.text('Show you aced the course'), findsOneWidget);
    // Kalkulus 1 is already verified, so it is not offered.
    await _tap(tester, find.text('Select'));
    expect(find.widgetWithText(ListTile, 'Kalkulus 1'), findsNothing);
    await _tap(tester, find.text('Fisika Dasar'));
    await _tap(tester, find.text('Use a sample KHS (preview)'));
    expect(find.text('KHS_sample.pdf'), findsOneWidget);
    await _tap(tester, find.text('Next'));

    expect(find.text('How much per hour?'), findsOneWidget);
    expect(find.text('Rp15.000'), findsOneWidget);
    expect(find.text('Rp40.000'), findsOneWidget);
    await _tap(tester, find.textContaining('graded assignments'));
    await _tap(tester, find.textContaining('meet on campus'));
    await _tap(tester, find.text('Submit for verification'));

    expect(find.text('We’re checking your KHS'), findsOneWidget);
    expect(find.text('Admin review'), findsOneWidget);
  });
}
