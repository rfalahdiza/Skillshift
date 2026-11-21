import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillshift/core/auth/app_session.dart';
import 'package:skillshift/core/router/redirect.dart';
import 'package:skillshift/core/router/routes.dart';

class _Tick extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final _tick = NotifierProvider<_Tick, int>(_Tick.new);

AppSession _user(UserRole? role) =>
    AppSession(userId: 'u1', email: 'a@student.ub.ac.id', role: role);

String? _go(
  String location,
  AsyncValue<AppSession?> session, {
  bool splashDone = true,
  bool dev = false,
}) => resolveRedirect(
  location: location,
  session: session,
  splashDone: splashDone,
  allowDevRoutes: dev,
);

void main() {
  group('splash and loading', () {
    test('holds on splash until splash time passes', () {
      expect(_go('/', const AsyncData(null), splashDone: false), isNull);
      expect(
        _go('/learner', const AsyncData(null), splashDone: false),
        Routes.splash,
      );
    });

    test('holds on splash while restoring the session', () {
      expect(_go('/', const AsyncLoading()), isNull);
    });

    test('a reload with previous data does not bounce to splash', () async {
      // Produce AsyncLoading-with-previous-data the way Riverpod does on a
      // rebuild, without touching internal APIs.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final p = FutureProvider<AppSession?>((ref) async {
        ref.watch(_tick);
        return _user(UserRole.learner);
      });
      container.listen(p, (_, _) {});
      await container.read(p.future);
      container.read(_tick.notifier).bump();
      final reloading = container.read(p);
      expect(reloading.isLoading, isTrue);
      expect(reloading.hasValue, isTrue);
      expect(_go('/learner', reloading), isNull);
    });
  });

  group('signed out', () {
    test('splash goes to onboarding', () {
      expect(_go('/', const AsyncData(null)), Routes.onboarding);
    });

    test('public pages are allowed', () {
      for (final p in [Routes.onboarding, Routes.signIn, Routes.verify]) {
        expect(_go(p, const AsyncData(null)), isNull, reason: p);
      }
    });

    test('protected pages go to onboarding', () {
      expect(_go('/admin', const AsyncData(null)), Routes.onboarding);
      expect(_go('/choose-role', const AsyncData(null)), Routes.onboarding);
    });

    test('profile load error counts as signed out', () {
      final err = AsyncError<AppSession?>(Exception('x'), StackTrace.empty);
      expect(_go('/learner', err), Routes.onboarding);
    });
  });

  group('signed in', () {
    test('without a role must choose one', () {
      expect(_go('/learner', AsyncData(_user(null))), Routes.chooseRole);
      expect(_go('/choose-role', AsyncData(_user(null))), isNull);
    });

    test('public pages and choose-role send to the role home', () {
      final s = AsyncData(_user(UserRole.mentor));
      expect(_go('/sign-in', s), Routes.mentorHome);
      expect(_go('/choose-role', s), Routes.mentorHome);
      expect(_go('/', s), Routes.mentorHome);
    });

    test('each role is confined to its own area', () {
      final learner = AsyncData(_user(UserRole.learner));
      expect(_go('/learner/find', learner), isNull);
      expect(_go('/admin', learner), Routes.learnerHome);
      expect(_go('/admin/applications', learner), Routes.learnerHome);
      expect(_go('/mentor/earnings', learner), Routes.learnerHome);
      // Prefix match must be on a path segment boundary.
      expect(_go('/learnerx', learner), Routes.learnerHome);

      final admin = AsyncData(_user(UserRole.admin));
      expect(_go('/admin/payments', admin), isNull);
      expect(_go('/learner', admin), Routes.adminDashboard);
    });
  });

  test('dev routes only when allowed', () {
    expect(_go('/dev/components', const AsyncData(null)), Routes.splash);
    expect(_go('/dev/components', const AsyncData(null), dev: true), isNull);
  });
}
