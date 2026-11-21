import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/badges.dart';
import '../../shared/widgets/brand.dart';
import '../auth/app_session.dart';
import '../auth/session_controller.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'nav_items.dart';

/// One shell per role. Picks the layout from the available width:
/// < 600 bottom nav · 600–899 bottom nav, centered content · ≥ 900 sidebar.
class AdaptiveShell extends ConsumerWidget {
  const AdaptiveShell({
    super.key,
    required this.role,
    required this.navigationShell,
  });

  final UserRole role;
  final StatefulNavigationShell navigationShell;

  void _go(int branch) => navigationShell.goBranch(
    branch,
    initialLocation: branch == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = navItemsFor(role);
    final session = ref.watch(sessionProvider).value;
    final preview = session?.isPreview ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width >= Breakpoints.wide) {
          return Scaffold(
            body: Row(
              children: [
                AppSidebar(
                  items: items,
                  currentBranch: navigationShell.currentIndex,
                  onSelect: _go,
                  session: session,
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      if (preview) const _PreviewStrip(),
                      Expanded(child: navigationShell),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final phoneItems = items.where((i) => i.phone).toList();
        Widget body = navigationShell;
        if (width >= Breakpoints.phone) {
          body = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Breakpoints.compactMaxWidth,
              ),
              child: body,
            ),
          );
        }
        return Scaffold(
          body: Column(
            children: [
              if (preview)
                const SafeArea(bottom: false, child: _PreviewStrip()),
              Expanded(child: body),
            ],
          ),
          bottomNavigationBar: AppBottomNav(
            items: phoneItems,
            currentBranch: navigationShell.currentIndex,
            onSelect: _go,
          ),
        );
      },
    );
  }
}

/// Figma `Navigation/Bottom Bar`.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentBranch,
    required this.onSelect,
  });

  final List<NavItem> items;
  final int currentBranch;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: _BottomNavButton(
                  item: item,
                  selected: item.branch == currentBranch,
                  onTap: () => onSelect(item.branch),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textTertiary;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        highlightShape: BoxShape.rectangle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: AppText.caption.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Figma `Navigation/Sidebar` (248 px).
class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.items,
    required this.currentBranch,
    required this.onSelect,
    required this.session,
  });

  final List<NavItem> items;
  final int currentBranch;
  final ValueChanged<int> onSelect;
  final AppSession? session;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    width: Breakpoints.sidebarWidth,
    color: AppColors.surface,
    child: SafeArea(
      right: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.xxl,
          Space.lg,
          Space.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: Space.sm),
              child: BrandLockup(),
            ),
            const SizedBox(height: Space.xxl),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _SidebarButton(
                  item: item,
                  selected: item.branch == currentBranch,
                  onTap: () => onSelect(item.branch),
                ),
              ),
            const Spacer(),
            if (session != null) _UserChip(session: session!),
          ],
        ),
      ),
    ),
  );
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.primaryPressed : AppColors.textPrimary;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primarySoft : Colors.transparent,
        borderRadius: Radii.rMd,
        child: InkWell(
          borderRadius: Radii.rMd,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: 11,
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: fg),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    item.wideLabel ?? item.label,
                    style: AppText.bodyMedium.copyWith(color: fg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserChip extends ConsumerWidget {
  const _UserChip({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
    color: AppColors.canvas,
    borderRadius: Radii.rMd,
    child: PopupMenuButton<String>(
      tooltip: 'Account',
      position: PopupMenuPosition.over,
      onSelected: (v) {
        if (v == 'signout') ref.read(sessionProvider.notifier).signOut();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'signout',
          child: Row(
            children: [
              Icon(AppIcons.logout, size: 18),
              SizedBox(width: Space.md),
              Text('Sign out'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Row(
          children: [
            AppAvatar(name: session.displayName, size: 36),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.displayName,
                    style: AppText.smallSemibold,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    session.role?.label ?? '',
                    style: AppText.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              AppIcons.chevronDown,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Thin warning strip shown on every screen of the debug-only preview.
class _PreviewStrip extends StatelessWidget {
  const _PreviewStrip();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: AppColors.warningSoft,
    padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 6),
    child: Text(
      'Dev preview · offline sample data · not signed in',
      textAlign: TextAlign.center,
      style: AppText.caption.copyWith(color: AppColors.warning),
    ),
  );
}
