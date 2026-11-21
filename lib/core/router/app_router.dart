import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dev/component_gallery_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/admin/admin_lists_screen.dart';
import '../../features/admin/applications_screen.dart';
import '../../features/admin/review_screen.dart';
import '../../features/auth/choose_role_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/verify_code_screen.dart';
import '../../features/learner/book_session_screen.dart';
import '../../features/learner/checkout_screen.dart';
import '../../features/learner/payment_screen.dart';
import '../../features/learner/session_screen.dart';
import '../../features/learner/home_screen.dart';
import '../../features/learner/matches_screen.dart';
import '../../features/learner/mentor_profile_screen.dart';
import '../../features/learner/quiz_screen.dart';
import '../../features/learner/timetable_screen.dart';
import '../../features/mentor/earnings_screen.dart';
import '../../features/mentor/mentor_apply_screen.dart';
import '../../features/mentor/mentor_home_screen.dart';
import '../../features/mentor/mentor_pending_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../auth/app_session.dart';
import '../auth/session_controller.dart';
import '../layout/adaptive_shell.dart';
import 'redirect.dart';
import 'routes.dart';

/// Minimum time the L01 splash stays up.
final splashDoneProvider = FutureProvider<bool>((ref) async {
  await Future<void>.delayed(const Duration(milliseconds: 1200));
  return true;
});

final routerProvider = Provider<GoRouter>((ref) {
  // Bridge Riverpod state changes into GoRouter's refresh mechanism.
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(sessionProvider, (_, _) => refresh.value++)
    ..listen(splashDoneProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) => resolveRedirect(
      location: state.uri.toString(),
      session: ref.read(sessionProvider),
      splashDone: ref.read(splashDoneProvider).value ?? false,
      allowDevRoutes: kDebugMode,
    ),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: Routes.verify,
        builder: (_, state) =>
            VerifyCodeScreen(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(
        path: Routes.chooseRole,
        builder: (_, _) => const ChooseRoleScreen(),
      ),
      // Learner full-screen flows, above the shell. Listed before the shell
      // so their paths win over the /learner branch.
      GoRoute(
        path: Routes.learnerSetupTimetable,
        builder: (_, _) => const TimetableScreen(setup: true),
      ),
      GoRoute(
        path: Routes.learnerSetupQuiz,
        builder: (_, _) => const QuizScreen(setup: true),
      ),
      GoRoute(path: Routes.learnerQuiz, builder: (_, _) => const QuizScreen()),
      GoRoute(
        path: '/learner/mentor/:id',
        builder: (_, state) =>
            MentorProfileScreen(mentorId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/learner/book/:id',
        builder: (_, state) =>
            BookSessionScreen(mentorId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.learnerCheckout,
        builder: (_, state) =>
            CheckoutScreen(args: state.extra as CheckoutArgs?),
      ),
      GoRoute(
        path: '/learner/pay/:id',
        builder: (_, state) => PaymentScreen(
          bookingId: state.pathParameters['id']!,
          args: state.extra as PaymentArgs?,
        ),
      ),
      GoRoute(
        path: '/learner/booked/:id',
        builder: (_, state) =>
            BookingConfirmedScreen(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/learner/session/:id',
        builder: (_, state) =>
            SessionScreen(bookingId: state.pathParameters['id']!),
      ),
      // Mentor full-screen flows (M01-M03, session detail).
      GoRoute(
        path: Routes.mentorApply,
        builder: (_, _) => const MentorApplyScreen(),
      ),
      GoRoute(
        path: Routes.mentorApplyPrice,
        builder: (_, state) =>
            MentorPriceScreen(args: state.extra as ApplyArgs?),
      ),
      GoRoute(
        path: Routes.mentorPending,
        builder: (_, _) => const MentorPendingScreen(),
      ),
      GoRoute(
        path: '/mentor/session/:id',
        builder: (_, state) =>
            SessionScreen(bookingId: state.pathParameters['id']!),
      ),
      // Admin review (AD03 / A03), above the shell.
      GoRoute(
        path: '/admin/applications/:id',
        builder: (_, state) =>
            ReviewScreen(applicationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.devComponents,
        builder: (_, _) => const ComponentGalleryScreen(),
      ),
      _learnerShell(),
      _mentorShell(),
      _adminShell(),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

StatefulShellBranch _tab(String path, Widget page) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, _) => page)],
);

StatefulShellRoute _learnerShell() => StatefulShellRoute.indexedStack(
  builder: (_, _, shell) =>
      AdaptiveShell(role: UserRole.learner, navigationShell: shell),
  branches: [
    _tab(Routes.learnerHome, const LearnerHomeScreen()),
    _tab(Routes.learnerFind, const MatchesScreen()),
    _tab(Routes.learnerTimetable, const TimetableScreen()),
    _tab(Routes.learnerSessions, const LearnerSessionsScreen()),
    _tab(Routes.learnerProfile, const ProfileScreen(role: UserRole.learner)),
  ],
);

StatefulShellRoute _mentorShell() => StatefulShellRoute.indexedStack(
  builder: (_, _, shell) =>
      AdaptiveShell(role: UserRole.mentor, navigationShell: shell),
  branches: [
    _tab(Routes.mentorHome, const MentorHomeScreen()),
    _tab(Routes.mentorSessions, const MentorSessionsScreen()),
    _tab(Routes.mentorEarnings, const EarningsScreen()),
    _tab(Routes.mentorProfile, const ProfileScreen(role: UserRole.mentor)),
  ],
);

StatefulShellRoute _adminShell() => StatefulShellRoute.indexedStack(
  builder: (_, _, shell) =>
      AdaptiveShell(role: UserRole.admin, navigationShell: shell),
  branches: [
    _tab(Routes.adminDashboard, const AdminDashboardScreen()),
    _tab(Routes.adminApplications, const ApplicationsScreen()),
    _tab(Routes.adminMentors, const AdminMentorsScreen()),
    _tab(Routes.adminSessions, const AdminSessionsScreen()),
    _tab(Routes.adminPayments, const AdminPaymentsScreen()),
    _tab(Routes.adminSettings, const AdminSettingsScreen()),
  ],
);
