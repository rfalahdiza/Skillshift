import 'package:flutter/widgets.dart';

import '../auth/app_session.dart';
import '../theme/app_icons.dart';

/// One destination in the bottom nav (phone) or sidebar (wide).
class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.branch,
    this.wideLabel,
    this.phone = true,
  });

  final String label;

  /// Longer sidebar label ("Find mentors" vs "Find").
  final String? wideLabel;
  final IconData icon;

  /// Index of the StatefulShellRoute branch.
  final int branch;

  /// Shown in the phone bottom nav. Sidebar shows every item.
  final bool phone;
}

/// Destinations per role, matching L08/M04/AD01 (phone) and T01/T04/A01
/// (sidebar). Branch order must match the router's shell branches.
List<NavItem> navItemsFor(UserRole role) => switch (role) {
  UserRole.learner => const [
    NavItem(label: 'Home', icon: AppIcons.home, branch: 0),
    NavItem(
      label: 'Find',
      wideLabel: 'Find mentors',
      icon: AppIcons.search,
      branch: 1,
    ),
    NavItem(
      label: 'Timetable',
      icon: AppIcons.calendar,
      branch: 2,
      phone: false,
    ),
    NavItem(label: 'Sessions', icon: AppIcons.book, branch: 3),
    NavItem(label: 'Profile', icon: AppIcons.user, branch: 4),
  ],
  UserRole.mentor => const [
    NavItem(label: 'Home', icon: AppIcons.home, branch: 0),
    NavItem(label: 'Sessions', icon: AppIcons.calendar, branch: 1),
    NavItem(label: 'Earnings', icon: AppIcons.wallet, branch: 2),
    NavItem(label: 'Profile', icon: AppIcons.user, branch: 3),
  ],
  UserRole.admin => const [
    NavItem(label: 'Dashboard', icon: AppIcons.dashboard, branch: 0),
    NavItem(label: 'Applications', icon: AppIcons.file, branch: 1),
    NavItem(label: 'Mentors', icon: AppIcons.users, branch: 2, phone: false),
    NavItem(
      label: 'Sessions',
      icon: AppIcons.calendar,
      branch: 3,
      phone: false,
    ),
    NavItem(label: 'Payments', icon: AppIcons.wallet, branch: 4),
    NavItem(label: 'Settings', icon: AppIcons.settings, branch: 5),
  ],
};
