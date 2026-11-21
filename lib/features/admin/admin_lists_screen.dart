import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_controller.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/time.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/surfaces.dart';
import 'admin_dashboard_screen.dart';

/// Shared page frame for the simple admin lists.
class _AdminPage extends ConsumerWidget {
  const _AdminPage({
    required this.title,
    required this.subtitle,
    required this.children,
    required this.onRefresh,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
    child: RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, c) {
          final pad = c.maxWidth >= 860 ? Space.xxl : Space.pageH;
          return ListView(
            padding: EdgeInsets.fromLTRB(pad, Space.xl, pad, Space.xxl),
            children: [
              Text(title, style: AppText.h1),
              Text(
                subtitle,
                style: AppText.small.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: Space.lg),
              ...children,
            ],
          );
        },
      ),
    ),
  );
}

StatusBadge _paymentBadge(String status) => switch (status) {
  'held' => const StatusBadge(
    'Held',
    tone: BadgeTone.info,
    icon: AppIcons.lock,
  ),
  'released' => const StatusBadge('Released', icon: AppIcons.verified),
  'pending' => const StatusBadge.pending(label: 'Not paid'),
  'refunded' => const StatusBadge('Refunded', tone: BadgeTone.neutral),
  'expired' => const StatusBadge('Expired', tone: BadgeTone.neutral),
  'failed' => const StatusBadge.rejected(label: 'Failed'),
  _ => StatusBadge(status, tone: BadgeTone.neutral),
};

/// Admin "Payments": every payment, all Midtrans SANDBOX.
class AdminPaymentsScreen extends ConsumerWidget {
  const AdminPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(adminPaymentsProvider);
    return _AdminPage(
      title: 'Payments',
      subtitle: 'Held until both sides confirm attendance.',
      onRefresh: () async {
        refreshAdmin(ref);
        await ref.read(adminPaymentsProvider.future);
      },
      children: [
        const InfoBanner(
          tone: BannerTone.warning,
          text:
              'Midtrans sandbox: these are test transactions. Payouts to '
              'mentors are simulated; no real money moves.',
        ),
        const SizedBox(height: Space.lg),
        ...list.when(
          loading: () => [const LoadingView()],
          error: (e, _) => [ErrorView(message: e.toString())],
          data: (rows) => rows.isEmpty
              ? [
                  const EmptyView(
                    icon: AppIcons.wallet,
                    title: 'No payments yet',
                  ),
                ]
              : [
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: Column(
                      children: [
                        for (final (i, p) in rows.indexed) ...[
                          if (i > 0) const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: Space.md,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${p.learnerName} → ${p.mentorName}',
                                        style: AppText.smallSemibold,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${p.courseName} · '
                                        '${(p.method ?? '').toUpperCase()} · '
                                        '${fmtDayMonth(p.createdAt)}',
                                        style: AppText.caption.copyWith(
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      formatRupiah(p.gross),
                                      style: AppText.smallSemibold,
                                    ),
                                    Text(
                                      'fee ${formatRupiah(p.fee)}',
                                      style: AppText.caption.copyWith(
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: Space.md),
                                SizedBox(
                                  width: 96,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: _paymentBadge(p.status),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
        ),
      ],
    );
  }
}

/// Admin "Mentors" (sidebar only): approved applications.
class AdminMentorsScreen extends ConsumerWidget {
  const AdminMentorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(applicationsProvider);
    return _AdminPage(
      title: 'Mentors',
      subtitle: 'Verified mentors and the courses they teach.',
      onRefresh: () async {
        refreshAdmin(ref);
        await ref.read(applicationsProvider.future);
      },
      children: [
        ...apps.when(
          loading: () => [const LoadingView()],
          error: (e, _) => [ErrorView(message: e.toString())],
          data: (list) {
            final approved = list
                .where(
                  (a) => a.application.status == ApplicationStatus.approved,
                )
                .toList();
            if (approved.isEmpty) {
              return [
                const EmptyView(icon: AppIcons.users, title: 'No mentors yet'),
              ];
            }
            return [
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: Column(
                  children: [
                    for (final (i, a) in approved.indexed) ...[
                      if (i > 0) const Divider(),
                      InkWell(
                        onTap: () =>
                            context.push(Routes.adminReview(a.application.id)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: Space.md,
                          ),
                          child: Row(
                            children: [
                              AppAvatar(name: a.mentorName, size: 36),
                              const SizedBox(width: Space.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.mentorName,
                                      style: AppText.smallSemibold,
                                    ),
                                    Text(
                                      '${a.application.courseName} · '
                                      '${formatRupiah(a.application.pricePerHour)}/hr'
                                      ' · ${a.proofLabel}',
                                      style: AppText.caption.copyWith(
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (a.isTestData) const StatusBadge.sample(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ];
          },
        ),
      ],
    );
  }
}

/// Admin "Sessions" (sidebar only): all bookings.
class AdminSessionsScreen extends ConsumerWidget {
  const AdminSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(adminBookingsProvider);
    return _AdminPage(
      title: 'Sessions',
      subtitle: 'Every booking, newest first.',
      onRefresh: () async {
        refreshAdmin(ref);
        await ref.read(adminBookingsProvider.future);
      },
      children: [
        ...list.when(
          loading: () => [const LoadingView()],
          error: (e, _) => [ErrorView(message: e.toString())],
          data: (rows) => rows.isEmpty
              ? [const EmptyView(icon: AppIcons.calendar, title: 'No sessions')]
              : [
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: Column(
                      children: [
                        for (final (i, b) in rows.indexed) ...[
                          if (i > 0) const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: Space.md,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${b.courseName}: '
                                        '${b.counterpartName ?? ''}',
                                        style: AppText.smallSemibold,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${fmtDate(b.startsAt)}, '
                                        '${fmtTime(b.startsAt)} · '
                                        '${b.isFreeTrial ? 'Free trial' : 'Paid'}'
                                        ' · ${b.place}',
                                        style: AppText.caption.copyWith(
                                          color: AppColors.textTertiary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                StatusBadge(
                                  b.status.label,
                                  tone: switch (b.status) {
                                    BookingStatus.completed ||
                                    BookingStatus.accepted => BadgeTone.success,
                                    BookingStatus.requested =>
                                      BadgeTone.warning,
                                    _ => BadgeTone.neutral,
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
        ),
      ],
    );
  }
}

/// Admin "Settings": business rules from app_config (read-only here).
class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(appConfigProvider);
    return _AdminPage(
      title: 'Settings',
      subtitle: 'Business rules enforced by the database.',
      onRefresh: () async {
        ref.invalidate(appConfigProvider);
        await ref.read(appConfigProvider.future);
      },
      children: [
        ...cfg.when(
          loading: () => [const LoadingView()],
          error: (e, _) => [ErrorView(message: e.toString())],
          data: (c) => [
            AppCard(
              child: Column(
                children: [
                  KeyValueRow(
                    icon: AppIcons.wallet,
                    label: 'Platform fee',
                    value: '${c.platformFeePercent}%',
                  ),
                  KeyValueRow(
                    icon: AppIcons.trendingUp,
                    label: 'Suggested price',
                    value:
                        '${formatRupiah(c.priceMin)} to '
                        '${formatRupiah(c.priceMax)} / hr',
                  ),
                  KeyValueRow(
                    icon: AppIcons.gift,
                    label: 'Free trial',
                    value: '${c.freeTrialMinutes} min, once per pair',
                  ),
                  KeyValueRow(
                    icon: AppIcons.verified,
                    label: 'Minimum GPA',
                    value: c.minGpa.toStringAsFixed(2),
                  ),
                  KeyValueRow(
                    icon: AppIcons.mail,
                    label: 'Sign-up domains',
                    value: c.allowedDomains.join(', '),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                const StatusBadge('Planned', tone: BadgeTone.neutral),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    'Editing these values in the app',
                    style: AppText.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: Space.xxl),
        AppButton.secondary(
          label: 'Sign out',
          icon: AppIcons.logout,
          onPressed: () => ref.read(sessionProvider.notifier).signOut(),
        ),
      ],
    );
  }
}
