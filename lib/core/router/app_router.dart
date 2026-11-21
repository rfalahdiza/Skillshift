import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dev/component_gallery_screen.dart';
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
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../shared/widgets/phase_placeholder.dart';
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

PhasePlaceholder _ph(
  String title,
  String id,
  int phase, {
  bool signOut = false,
  String? description,
}) => PhasePlaceholder(
  title: title,
  screenId: id,
  phase: phase,
  showSignOut: signOut,
  description: description,
);

StatefulShellRoute _learnerShell() => StatefulShellRoute.indexedStack(
  builder: (_, _, shell) =>
      AdaptiveShell(role: UserRole.learner, navigationShell: shell),
  branches: [
    _tab(Routes.learnerHome, const LearnerHomeScreen()),
    _tab(Routes.learnerFind, const MatchesScreen()),
    _tab(Routes.learnerTimetable, const TimetableScreen()),
    _tab(Routes.learnerSessions, const LearnerSessionsScreen()),
    _tab(
      Routes.learnerProfile,
      _ph(
        'Profile',
        '—',
        6,
        signOut: true,
        description:
            'Editing your profile is planned. Ratings and chat are not '
            'part of this prototype.',
      ),
    ),
  ],
);

StatefulShellRoute _mentorShell() => StatefulShellRoute.indexedStack(
  builder: (_, _, shell) =>
      AdaptiveShell(role: UserRole.mentor, navigationShell: shell),
  branches: [
    _tab(Routes.mentorHome, _ph('Home', 'M04 · T04', 4)),
    _tab(Routes.mentorSessions, _ph('Sessions', '—', 4)),
    _tab(
      Routes.mentorEarnings,
      _ph(
        'Earnings',
        'M05 · T05',
        4,
        description:
            'Arrives in Phase 4. Payouts will be simulated: '
            'no real money is transferred.',
      ),
    ),
    _tab(Routes.mentorProfile, _ph('Profile', '—', 4, signOut: true)),
  ],
);

StatefulShellRoute _adminShell() => StatefulShellRoute.indexedStack(
  builder: (_, _, shell) =>
      AdaptiveShell(role: UserRole.admin, navigationShell: shell),
  branches: [
    _tab(Routes.adminDashboard, _ph('Dashboard', 'AD01 · A01', 5)),
    _tab(Routes.adminApplications, _ph('Applications', 'AD02 · A02', 5)),
    _tab(Routes.adminMentors, _ph('Mentors', '—', 5)),
    _tab(Routes.adminSessions, _ph('Sessions', '—', 5)),
    _tab(
      Routes.adminPayments,
      _ph(
        'Payments',
        '—',
        5,
        description:
            'Arrives in Phase 5. Payments are Midtrans sandbox '
            'test transactions only.',
      ),
    ),
    _tab(Routes.adminSettings, _ph('Settings', '—', 5, signOut: true)),
  ],
);
