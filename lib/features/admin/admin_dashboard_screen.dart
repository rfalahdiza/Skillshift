import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/surfaces.dart';
import 'admin_widgets.dart';

void refreshAdmin(WidgetRef ref) => ref
  ..invalidate(adminStatsProvider)
  ..invalidate(activityProvider)
  ..invalidate(applicationsProvider)
  ..invalidate(adminPaymentsProvider)
  ..invalidate(adminBookingsProvider);

/// AD01 Dashboard (phone) / A01 (wide: table + recent activity).
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final apps = ref.watch(applicationsProvider);
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          refreshAdmin(ref);
          await ref.read(adminStatsProvider.future);
        },
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 860;
            final pending =
                (apps.value ?? const <AdminApplication>[])
                    .where(
                      (a) => a.application.status == ApplicationStatus.pending,
                    )
                    .toList()
                  ..sort(
                    (a, b) => a.application.createdAt.compareTo(
                      b.application.createdAt,
                    ),
                  );

            final header = Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wide ? fmtDate(DateTime.now()) : 'Admin',
                        style: AppText.small.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text('Dashboard', style: AppText.h1),
                    ],
                  ),
                ),
                const AppAvatar(
                  name: 'Admin SkillShift',
                  size: 44,
                  tone: AvatarTone.blue,
                ),
              ],
            );

            final cards = stats.when(
              loading: () => <Widget>[const LoadingView()],
              error: (e, _) => <Widget>[
                ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(adminStatsProvider),
                ),
              ],
              data: (s) => [
                StatCard(
                  icon: AppIcons.file,
                  tone: BadgeTone.warning,
                  value: '${s.pendingApplications}',
                  label: wide ? 'Pending applications' : 'Pending',
                  hint: wide && s.oldestPending != null
                      ? 'Oldest: ${ago(s.oldestPending!)}'
                      : null,
                ),
                StatCard(
                  icon: AppIcons.verified,
                  tone: BadgeTone.success,
                  value: '${s.verifiedMentors}',
                  label: 'Verified mentors',
                ),
                StatCard(
                  icon: AppIcons.calendar,
                  tone: BadgeTone.neutral,
                  value: '${s.sessionsThisWeek}',
                  label: 'Sessions this week',
                ),
                StatCard(
                  icon: AppIcons.wallet,
                  tone: BadgeTone.info,
                  value: compactRupiah(s.onHoldAmount),
                  label: 'On hold (sandbox)',
                  hint: wide ? 'Midtrans sandbox' : null,
                ),
              ],
            );

            final grid = cards.length == 1
                ? cards.first
                : wide
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(width: Space.md),
                          Expanded(child: cards[i]),
                        ],
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: Space.md),
                          Expanded(child: cards[1]),
                        ],
                      ),
                      const SizedBox(height: Space.md),
                      Row(
                        children: [
                          Expanded(child: cards[2]),
                          const SizedBox(width: Space.md),
                          Expanded(child: cards[3]),
                        ],
                      ),
                    ],
                  );

            final review = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  'Needs review',
                  action: wide ? 'View all applications' : 'See all',
                  onAction: () => context.go(Routes.adminApplications),
                ),
                if (apps.isLoading && apps.value == null)
                  const LoadingView()
                else if (pending.isEmpty)
                  AppCard(
                    child: Text(
                      'Nothing to review. New mentor applications show up '
                      'here.',
                      style: AppText.small.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else if (wide)
                  ApplicationsTable(apps: pending.take(6).toList())
                else
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: Column(
                      children: [
                        for (final (i, a) in pending.take(3).indexed) ...[
                          if (i > 0) const Divider(),
                          ApplicationTile(
                            app: a,
                            onTap: () => context.push(
                              Routes.adminReview(a.application.id),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );

            if (!wide) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.pageH,
                  Space.xl,
                  Space.pageH,
                  Space.xxl,
                ),
                children: [
                  header,
                  const SizedBox(height: Space.xl),
                  grid,
                  const SizedBox(height: Space.xxl),
                  review,
                ],
              );
            }
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Space.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  const SizedBox(height: Space.xl),
                  grid,
                  const SizedBox(height: Space.xxl),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: review),
                      const SizedBox(width: Space.xxl),
                      const SizedBox(width: 320, child: _RecentActivity()),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(activityProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Recent activity'),
        items.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: e.toString()),
          data: (list) => AppCard(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Column(
              children: [
                for (final (i, a) in list.indexed) ...[
                  if (i > 0) const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.subtle,
                            borderRadius: Radii.rSm,
                          ),
                          child: Icon(
                            activityIcon(a.kind),
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.title, style: AppText.smallSemibold),
                              Text(
                                '${a.subtitle} · ${ago(a.at)}',
                                style: AppText.caption.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A01/A02 wide table of applications.
class ApplicationsTable extends StatelessWidget {
  const ApplicationsTable({super.key, required this.apps, this.minGpa = 3.5});

  final List<AdminApplication> apps;
  final double minGpa;

  static const _flex = [4, 3, 2, 3, 3, 2];

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        const TableHeader(
          columns: ['Applicant', 'Course', 'Proof', 'Submitted', 'Status', ''],
          flex: _flex,
        ),
        for (final (i, a) in apps.indexed) ...[
          if (i > 0) const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: Space.md,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: _flex[0],
                  child: Row(
                    children: [
                      AppAvatar(name: a.mentorName, size: 32),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.mentorName,
                              style: AppText.smallSemibold,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${a.program ?? ''} ${a.cohortYear ?? ''}',
                              style: AppText.caption.copyWith(
                                color: AppColors.textTertiary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: _flex[1],
                  child: Text(
                    a.application.courseName,
                    style: AppText.small,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: _flex[2],
                  child: Text(a.proofLabel, style: AppText.small),
                ),
                Expanded(
                  flex: _flex[3],
                  child: Text(
                    shortDate(a.application.createdAt, time: true),
                    style: AppText.small,
                  ),
                ),
                Expanded(
                  flex: _flex[4],
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: applicationBadge(a, minGpa: minGpa),
                  ),
                ),
                Expanded(
                  flex: _flex[5],
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: a.application.status == ApplicationStatus.pending
                        ? AppButton(
                            label: 'Review',
                            size: AppButtonSize.small,
                            expand: false,
                            onPressed: () => context.push(
                              Routes.adminReview(a.application.id),
                            ),
                          )
                        : AppButton.secondary(
                            label: 'View',
                            size: AppButtonSize.small,
                            expand: false,
                            onPressed: () => context.push(
                              Routes.adminReview(a.application.id),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}
