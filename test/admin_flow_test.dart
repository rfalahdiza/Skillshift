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

Future<void> _startAsAdmin(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: SkillShiftApp()));
  await _settle(tester);
  ProviderScope.containerOf(tester.element(find.byType(SkillShiftApp)))
      .read(sessionProvider.notifier)
      .startPreview(UserRole.admin);
  await _settle(tester);
}

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<AppButton>(find.widgetWithText(AppButton, label)).onPressed !=
    null;

void main() {
  testWidgets('dashboard: stats and needs-review list', (tester) async {
    await _startAsAdmin(tester, const Size(390, 1000));

    expect(find.text('Dashboard'), findsWidgets); // title + nav label
    expect(find.text('On hold (sandbox)'), findsOneWidget);
    expect(find.text('Rp450rb'), findsOneWidget);
    expect(find.text('Needs review'), findsOneWidget);
    // Oldest pending first: Bima (GPA 3.42) needs a manual check.
    expect(find.text('Bima Saputra'), findsOneWidget);
    expect(find.text('Needs check'), findsOneWidget);
  });

  testWidgets('applications: tabs, search, approve needs all checks', (
    tester,
  ) async {
    await _startAsAdmin(tester, const Size(390, 1000));

    await _tap(tester, find.text('Applications'));
    expect(find.text('Pending · 4'), findsOneWidget);
    expect(find.text('Approved · 1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'fajar');
    await _settle(tester);
    expect(find.text('Fajar Nugroho'), findsOneWidget);
    expect(find.text('Raka Pratama'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await _settle(tester);

    await _tap(tester, find.text('Raka Pratama'));
    expect(find.text('Review application'), findsOneWidget);
    expect(
      find.text('Seeded test application: there is no real KHS file.'),
      findsOneWidget,
    );
    expect(find.text('2451505••••••'.substring(0, 7)), findsNothing);
    expect(find.textContaining('••••••'), findsOneWidget); // NIM masked

    // Approve stays disabled until all three manual checks are ticked.
    expect(_enabled(tester, 'Approve'), isFalse);
    await _tap(tester, find.textContaining('Name on the KHS matches'));
    await _tap(tester, find.text('Grade for Kalkulus 1 is A'));
    await _tap(tester, find.text('Document is clear and complete'));
    expect(_enabled(tester, 'Approve'), isTrue);
    await _tap(tester, find.text('Approve'));

    expect(find.textContaining('is now a verified mentor'), findsOneWidget);
    expect(find.text('Pending · 3'), findsOneWidget);
    expect(find.text('Approved · 2'), findsOneWidget);
  });

  testWidgets('reject needs a reason', (tester) async {
    await _startAsAdmin(tester, const Size(390, 1000));

    await _tap(tester, find.text('Applications'));
    await _tap(tester, find.text('Fajar Nugroho'));
    await _tap(tester, find.text('Reject'));

    expect(find.text('Reject application?'), findsOneWidget);
    expect(_enabled(tester, 'Reject application'), isFalse);
    await _tap(tester, find.text('Name mismatch'));
    expect(_enabled(tester, 'Reject application'), isTrue);
    await _tap(tester, find.text('Reject application'));

    expect(find.textContaining('Application rejected'), findsOneWidget);
    expect(find.text('Rejected · 2'), findsOneWidget);
  });

  testWidgets('wide layouts: A01 table and A03 two panes', (tester) async {
    await _startAsAdmin(tester, const Size(1440, 900));

    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('Review'), findsWidgets);
    await _tap(tester, find.text('Review').first);
    expect(find.text('Review application'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.textContaining('Mentor applications /'), findsOneWidget);
  });
}
