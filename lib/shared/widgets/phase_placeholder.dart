import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_controller.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import 'app_button.dart';
import 'badges.dart';
import 'surfaces.dart';

/// Stand-in for a screen that is planned but not built yet. Deliberately
/// plain and labelled, so planned features never look finished.
class PhasePlaceholder extends ConsumerWidget {
  const PhasePlaceholder({
    super.key,
    required this.title,
    required this.screenId,
    required this.phase,
    this.description,
    this.showSignOut = false,
  });

  final String title;

  /// Figma frame id, e.g. "L08".
  final String screenId;
  final int phase;
  final String? description;
  final bool showSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.pageH,
        Space.xxl,
        Space.pageH,
        Space.xxl,
      ),
      children: [
        Text(title, style: AppText.display),
        const SizedBox(height: Space.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBadge(
                    'Planned · Phase $phase',
                    tone: BadgeTone.neutral,
                    icon: AppIcons.clock,
                  ),
                  Text(
                    screenId,
                    style: AppText.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              Text(
                description ??
                    'This screen is not built yet. It arrives in Phase $phase.',
                style: AppText.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (showSignOut) ...[
          const SizedBox(height: Space.xxl),
          AppButton.secondary(
            label: 'Sign out',
            icon: AppIcons.logout,
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          ),
        ],
      ],
    ),
  );
}
