import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/surfaces.dart';

/// L02 Onboarding: three short pages, then sign-in.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;

  static const _copy = [
    (
      'Learn from seniors who aced your course',
      'Get matched with verified UB mentors who are free when you are, right '
          'between your classes.',
    ),
    (
      'Your first session with each mentor is free',
      'Try 30 minutes before you pay. After that, pay per session with QRIS '
          'or a virtual account.',
    ),
    (
      'Paid only after you both show up',
      'SkillShift holds your payment and releases it to your mentor only '
          'after you both confirm attendance.',
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _toSignIn() => context.go(Routes.signIn);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _toSignIn,
                    child: Text(
                      'Skip',
                      style: AppText.smallMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _copy.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => _Page(
                      illustration: switch (i) {
                        0 => const _TimetableIllustration(),
                        1 => const _TrialIllustration(),
                        _ => const _HeldIllustration(),
                      },
                      title: _copy[i].$1,
                      body: _copy[i].$2,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.pageH,
                    Space.md,
                    Space.pageH,
                    Space.xxl,
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < _copy.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _index ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? AppColors.primary
                                : AppColors.borderStrong,
                            borderRadius: Radii.rFull,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(label: 'Get started', onPressed: _toSignIn),
              const SizedBox(height: Space.sm),
              AppButton.text(
                label: 'I already have an account',
                onPressed: _toSignIn,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.illustration,
    required this.title,
    required this.body,
  });

  final Widget illustration;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: Space.pageH),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        illustration,
        const SizedBox(height: Space.xxl),
        Text(title, style: AppText.display),
        const SizedBox(height: Space.md),
        Text(
          body,
          style: AppText.body.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

/// Page 1: a day with a free gap and a matched session (from the design).
class _TimetableIllustration extends StatelessWidget {
  const _TimetableIllustration();

  Widget _row(String time, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            time,
            style: AppText.small.copyWith(color: AppColors.textTertiary),
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );

  Widget _class(
    String name, {
    double widthFactor = 0.8,
  }) => FractionallySizedBox(
    alignment: Alignment.centerLeft,
    widthFactor: widthFactor,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.subtle,
        borderRadius: Radii.rSm,
      ),
      child: Text(name, style: AppText.small, overflow: TextOverflow.ellipsis),
    ),
  );

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Tuesday', style: AppText.h3)),
            const StatusBadge('Matched', icon: AppIcons.verified),
          ],
        ),
        const SizedBox(height: Space.md),
        _row('07:00', _class('Kalkulus 1')),
        _row(
          '09:30',
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 0.55,
            child: AppCard(
              dashed: true,
              radius: Radii.sm,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: 8,
              ),
              child: Text(
                'Free gap',
                style: AppText.small.copyWith(color: AppColors.primaryPressed),
              ),
            ),
          ),
        ),
        _row('10:20', _class('Pemrograman Dasar', widthFactor: 0.7)),
        _row(
          '12:00',
          Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: Radii.rMd,
            ),
            child: Row(
              children: [
                const _AvatarPair(),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kalkulus 1 with Raka',
                        style: AppText.smallSemibold.copyWith(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '12:00 to 13:00 · Gedung F',
                        style: AppText.caption.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _row('13:00', _class('Matematika Komputasi', widthFactor: 0.85)),
      ],
    ),
  );
}

class _AvatarPair extends StatelessWidget {
  const _AvatarPair();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 56,
    height: 34,
    child: Stack(
      children: [
        _circle('NP', AvatarTone.teal),
        Positioned(left: 22, child: _circle('RP', AvatarTone.coral)),
      ],
    ),
  );

  Widget _circle(String t, AvatarTone tone) => Container(
    width: 34,
    height: 34,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: tone.background,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.primary, width: 2),
    ),
    child: Text(t, style: AppText.caption.copyWith(color: tone.ink)),
  );
}

/// Page 2: free trial vs paid session.
class _TrialIllustration extends StatelessWidget {
  const _TrialIllustration();

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: [
        Row(
          children: [
            const AppAvatar(name: 'Raka Pratama', tone: AvatarTone.coral),
            const SizedBox(width: Space.md),
            Expanded(child: Text('Raka Pratama', style: AppText.h3)),
            const Icon(AppIcons.verified, color: AppColors.primary, size: 18),
          ],
        ),
        const SizedBox(height: Space.lg),
        Row(
          children: [
            Expanded(
              child: _option('Free trial', '30 min · Rp0', selected: true),
            ),
            const SizedBox(width: Space.md),
            Expanded(child: _option('Paid', '60 min · Rp25.000')),
          ],
        ),
      ],
    ),
  );

  Widget _option(String t, String s, {bool selected = false}) => Container(
    padding: const EdgeInsets.all(Space.md),
    decoration: BoxDecoration(
      color: selected ? AppColors.primarySoft : AppColors.surface,
      borderRadius: Radii.rMd,
      border: Border.all(
        color: selected ? AppColors.primary : AppColors.border,
        width: selected ? 1.5 : 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t, style: AppText.smallSemibold),
        Text(
          s,
          style: AppText.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

/// Page 3: payment held until both confirm.
class _HeldIllustration extends StatelessWidget {
  const _HeldIllustration();

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: [
        _person('Nadia Putri', 'You'),
        const Divider(height: Space.xl),
        _person('Raka Pratama', 'Mentor'),
        const SizedBox(height: Space.lg),
        const InfoBanner(
          text: 'Both confirmed. Rp22.500 released to Raka (simulated payout).',
        ),
      ],
    ),
  );

  Widget _person(String name, String role) => Row(
    children: [
      AppAvatar(name: name, size: 36),
      const SizedBox(width: Space.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: AppText.smallSemibold),
            Text(
              role,
              style: AppText.caption.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
      const StatusBadge('Confirmed', icon: AppIcons.verified),
    ],
  );
}
