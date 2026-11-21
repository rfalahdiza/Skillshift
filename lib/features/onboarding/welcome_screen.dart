import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/app_session.dart';
import '../../core/auth/session_controller.dart';
import '../../core/config/env.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/surfaces.dart';

/// Phase 1 stand-in for L02 Onboarding. The real carousel, sign-in and code
/// verification arrive in Phase 2. In debug builds it offers an offline
/// preview of each role's shell and the component gallery.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.read(sessionProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(Space.pageH),
              children: [
                const SizedBox(height: Space.xxxl),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: LogoMark(height: 48),
                ),
                const SizedBox(height: Space.xxl),
                Text(
                  'Learn from seniors who aced your course',
                  style: AppText.display,
                ),
                const SizedBox(height: Space.sm),
                Text(
                  'Get matched with verified UB mentors who are free when you '
                  'are, right between your classes.',
                  style: AppText.body.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: Space.xxl),
                const AppCard(
                  child: Row(
                    children: [
                      StatusBadge(
                        'Planned · Phase 2',
                        tone: BadgeTone.neutral,
                        icon: AppIcons.clock,
                      ),
                      SizedBox(width: Space.md),
                      Expanded(child: Text('Onboarding and UB email sign-in')),
                    ],
                  ),
                ),
                if (!Env.hasSupabase) ...[
                  const SizedBox(height: Space.md),
                  const InfoBanner(
                    tone: BannerTone.warning,
                    text:
                        'Supabase is not configured. Copy .env.example to '
                        '.env and run with --dart-define-from-file=.env.',
                  ),
                ],
                if (kDebugMode) ...[
                  const SizedBox(height: Space.xxxl),
                  const SectionLabel('Dev preview · debug builds only'),
                  Text(
                    'Opens a role\'s navigation shell offline, without signing '
                    'in. Screens inside are placeholders until their phase.',
                    style: AppText.small.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  for (final role in UserRole.values) ...[
                    AppButton.secondary(
                      label: 'Preview as ${role.name}',
                      onPressed: () => session.startPreview(role),
                    ),
                    const SizedBox(height: Space.sm),
                  ],
                  AppButton.text(
                    label: 'Component gallery',
                    onPressed: () => context.push(Routes.devComponents),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
