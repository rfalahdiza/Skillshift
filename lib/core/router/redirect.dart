import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/app_session.dart';
import 'routes.dart';

/// Pure role-guard logic, kept separate from GoRouter so it is unit-tested.
///
/// Returns the path to go to, or null to stay on [location].
String? resolveRedirect({
  required String location,
  required AsyncValue<AppSession?> session,
  required bool splashDone,
  bool allowDevRoutes = false,
}) {
  final path = Uri.parse(location).path;

  if (path.startsWith('/dev/')) {
    return allowDevRoutes ? null : Routes.splash;
  }

  // Hold on the splash until the brand moment and session restore finish.
  // (A reload that still has previous data does not bounce to the splash.)
  final restoring = session.isLoading && !session.hasValue;
  if (!splashDone || restoring) {
    return path == Routes.splash ? null : Routes.splash;
  }

  // A failed profile load is treated as signed out.
  final user = session.hasError ? null : session.value;

  if (user == null) {
    if (path == Routes.splash) return Routes.onboarding;
    return Routes.publicPaths.contains(path) ? null : Routes.onboarding;
  }

  final role = user.role;
  if (role == null) {
    return path == Routes.chooseRole ? null : Routes.chooseRole;
  }

  final home = Routes.homeFor(role);
  if (Routes.publicPaths.contains(path) || path == Routes.chooseRole) {
    return home;
  }

  // Each role may only open its own area.
  final ownPrefix = Routes.prefixFor(role);
  final inOwnArea = path == ownPrefix || path.startsWith('$ownPrefix/');
  return inOwnArea ? null : home;
}
