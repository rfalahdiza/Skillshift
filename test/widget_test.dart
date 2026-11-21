import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillshift/app.dart';
import 'package:skillshift/core/auth/app_session.dart';
import 'package:skillshift/core/auth/session_controller.dart';

/// Smoke test: app boots on the L01 splash, then (with no Supabase config,
/// as in CI) lands on the welcome screen.
void main() {
  testWidgets('shows splash, then welcome when signed out', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SkillShiftApp()));
    await tester.pump();

    expect(find.text('Peer learning for UB students'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(
      find.text('Learn from seniors who aced your course'),
      findsOneWidget,
    );
  });

  testWidgets('dev preview opens the learner shell with bottom nav', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: SkillShiftApp()));
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SkillShiftApp)),
    );
    container.read(sessionProvider.notifier).startPreview(UserRole.learner);
    await tester.pumpAndSettle();

    for (final label in ['Home', 'Find', 'Sessions', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }
    // Timetable is sidebar-only; not in the phone bottom nav.
    expect(find.text('Timetable'), findsNothing);
    expect(find.textContaining('Dev preview'), findsOneWidget);
  });

  testWidgets('wide layout uses the sidebar', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: SkillShiftApp()));
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    ProviderScope.containerOf(tester.element(find.byType(SkillShiftApp)))
        .read(sessionProvider.notifier)
        .startPreview(UserRole.learner);
    await tester.pumpAndSettle();

    expect(find.text('Find mentors'), findsOneWidget);
    expect(find.text('Timetable'), findsWidgets);
  });
}
