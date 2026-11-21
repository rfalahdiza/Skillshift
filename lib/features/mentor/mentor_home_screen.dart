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
import '../learner/home_screen.dart' show showComingSoon;

void _refreshMentor(WidgetRef ref) => ref
  ..invalidate(mentorOverviewProvider)
  ..invalidate(mentorBookingsProvider)
  ..invalidate(earningsProvider)
  ..invalidate(bookingsProvider);

/// M04 Mentor home (phone) / T04 (wide: upcoming on the right).
class MentorHomeScreen extends ConsumerWidget {
  const MentorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(sessionProvider).value?.firstName ?? '';
    final overview = ref.watch(mentorOverviewProvider);

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          _refreshMentor(ref);
          await ref.read(mentorOverviewProvider.future);
        },
        child: overview.when(
          loading: () => ListView(children: const [LoadingView()]),
          error: (e, _) => ListView(
            children: [
              ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(mentorOverviewProvider),
              ),
            ],
          ),
          data: (o) => LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 860;
              final header = _Header(name: name, overview: o);
              if (!o.isVerified) {
                return ListView(
                  padding: const EdgeInsets.all(Space.pageH),
                  children: [
                    header,
                    const SizedBox(height: Space.xl),
                    _NotVerified(overview: o),
                  ],
                );
              }
              final left = <Widget>[
                const _EarnedCard(),
                const SizedBox(height: Space.xxl),
                const _Requests(),
                const SizedBox(height: Space.xxl),
                if (!wide) ...[
                  const _Upcoming(),
                  const SizedBox(height: Space.xxl),
                ],
                _CoursesYouTeach(overview: o),
              ];
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
                    ...left,
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: left,
                          ),
                        ),
                        const SizedBox(width: Space.xxl),
                        const SizedBox(width: 340, child: _Upcoming()),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.overview});

  final String name;
  final MentorOverview overview;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi, $name', style: AppText.h1),
            const SizedBox(height: Space.xs),
            if (overview.isVerified)
              StatusBadge(
                'Verified mentor · '
                '${overview.courses.map((c) => c.courseName).join(', ')}',
                icon: AppIcons.verified,
              ),
          ],
        ),
      ),
      AppIconButton(
        icon: AppIcons.bell,
        tooltip: 'Notifications',
        onPressed: () => showComingSoon(context, 'Notifications'),
      ),
    ],
  );
}

/// Not verified yet: start, waiting, or rejected.
class _NotVerified extends StatelessWidget {
  const _NotVerified({required this.overview});

  final MentorOverview overview;

  @override
  Widget build(BuildContext context) {
    final pending = overview.latestPending;
    final rejected = overview.latestRejected;
    if (pending != null) {
      return AppCard(
        onTap: () => context.push(Routes.mentorPending),
        child: Row(
          children: [
            const Icon(AppIcons.clock, color: AppColors.warning),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('We’re checking your KHS', style: AppText.h3),
                  Text(
                    '${pending.courseName} · '
                    '${formatRupiah(pending.pricePerHour)}/hr',
                    style: AppText.small.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const StatusBadge.pending(),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rejected != null) ...[
          InfoBanner(
            tone: BannerTone.danger,
            icon: AppIcons.info,
            text:
                '${rejected.courseName} was not approved: '
                '${rejected.rejectReason ?? 'no reason given'}',
          ),
          const SizedBox(height: Space.lg),
        ],
        AppCard(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Earn in your class gaps', style: AppText.h2),
              const SizedBox(height: Space.xs),
              Text(
                'Upload your KHS showing an A in the course or a GPA of 3.5 or '
                'higher. An admin checks it, usually within a day.',
                style: AppText.small.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: Space.lg),
              AppButton(
                label: rejected != null ? 'Apply again' : 'Become a mentor',
                onPressed: () => context.push(Routes.mentorApply),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Navy card. Payouts are SIMULATED and labelled so.
class _EarnedCard extends ConsumerWidget {
  const _EarnedCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(earningsProvider).value;
    final net = e == null || e.lines.isEmpty ? null : e.lines.first.net;
    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(color: AppColors.navy, borderRadius: Radii.rLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'EARNED THIS MONTH',
                  style: AppText.overline.copyWith(color: Colors.white70),
                ),
              ),
              const StatusBadge.simulated(),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            formatRupiah(e?.thisMonth ?? 0),
            style: AppText.amount.copyWith(color: Colors.white),
          ),
          const SizedBox(height: Space.xs),
          Text(
            '${e?.paidSessionsThisMonth ?? 0} paid sessions'
            '${net == null ? '' : ' · ${formatRupiah(net)} per session after fee'}',
            style: AppText.small.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _Requests extends ConsumerStatefulWidget {
  const _Requests();

  @override
  ConsumerState<_Requests> createState() => _RequestsState();
}

class _RequestsState extends ConsumerState<_Requests> {
  String? _busy;

  Future<void> _respond(MentorBooking mb, bool accept) async {
    setState(() => _busy = mb.booking.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(repositoryProvider)
          .respondToBooking(mb.booking.id, accept: accept);
      _refreshMentor(ref);
      final first = (mb.booking.counterpartName ?? 'the learner')
          .split(' ')
          .first;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Accepted. $first can see it in Sessions.'
                : 'Declined.${mb.booking.isFreeTrial ? '' : ' Payment refunded (sandbox).'}',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(mentorBookingsProvider);
    final requests =
        list.value?.where((m) => m.isActionableRequest).toList() ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('New requests', style: AppText.h3)),
            if (requests.isNotEmpty)
              StatusBadge(
                '${requests.length} new',
                tone: BadgeTone.info,
                icon: AppIcons.info,
              ),
          ],
        ),
        const SizedBox(height: Space.md),
        if (list.isLoading && list.value == null)
          const LoadingView()
        else if (requests.isEmpty)
          AppCard(
            child: Text(
              'No new requests. Learners see you when they share a free gap '
              'with you.',
              style: AppText.small.copyWith(color: AppColors.textSecondary),
            ),
          )
        else
          for (final r in requests) ...[
            _RequestCard(
              request: r,
              busy: _busy == r.booking.id,
              onDecline: () => _respond(r, false),
              onAccept: () => _respond(r, true),
            ),
            const SizedBox(height: Space.md),
          ],
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.busy,
    required this.onDecline,
    required this.onAccept,
  });

  final MentorBooking request;
  final bool busy;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final b = request.booking;
    final name = b.counterpartName ?? 'Learner';
    return AppCard(
      padding: const EdgeInsets.all(Space.lg + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: name, size: 44),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppText.h3),
                    Text(
                      '${b.courseName} · '
                      '${b.isFreeTrial ? 'Free trial · 30 min' : 'Paid · ${b.durationMin} min'}',
                      style: AppText.small.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          AiReason(request.wantsLine),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.lg,
            runSpacing: Space.xs,
            children: [
              _IconText(
                AppIcons.clock,
                '${fmtDate(b.startsAt)}, ${fmtTime(b.startsAt)}',
              ),
              _IconText(
                AppIcons.wallet,
                b.isFreeTrial
                    ? 'Free trial'
                    : '${formatRupiah(b.gross ?? 0)} · paid, held',
              ),
              _IconText(AppIcons.pin, b.place),
            ],
          ),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Decline',
                  size: AppButtonSize.small,
                  onPressed: busy ? null : onDecline,
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: AppButton(
                  label: 'Accept',
                  size: AppButtonSize.small,
                  loading: busy,
                  onPressed: busy ? null : onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AppColors.textSecondary),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          style: AppText.small,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

class _Upcoming extends ConsumerWidget {
  const _Upcoming();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(mentorBookingsProvider).value ?? const [];
    final upcoming =
        list
            .where(
              (m) =>
                  m.booking.status == BookingStatus.accepted &&
                  m.booking.endsAt.isAfter(
                    DateTime.now().subtract(const Duration(hours: 24)),
                  ),
            )
            .toList()
          ..sort((a, b) => a.booking.startsAt.compareTo(b.booking.startsAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upcoming', style: AppText.h3),
        const SizedBox(height: Space.md),
        if (upcoming.isEmpty)
          AppCard(
            child: Text(
              'No accepted sessions yet.',
              style: AppText.small.copyWith(color: AppColors.textSecondary),
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Column(
              children: [
                for (final (i, m) in upcoming.indexed) ...[
                  if (i > 0) const Divider(),
                  MentorSessionTile(booking: m.booking),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// One row linking to the session (L15 reused for mentors).
class MentorSessionTile extends StatelessWidget {
  const MentorSessionTile({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final now = DateTime.now();
    final live = !now.isBefore(b.startsAt) && now.isBefore(b.endsAt);
    final name = b.counterpartName ?? 'Learner';
    final short = name.split(' ').length > 1
        ? '${name.split(' ').first} ${name.split(' ')[1][0]}.'
        : name;
    return InkWell(
      onTap: () => context.push(Routes.mentorSession(b.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          children: [
            AppAvatar(name: name, size: 40),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$short · ${b.courseName}', style: AppText.bodyMedium),
                  Text(
                    '${fmtDayNum(b.startsAt)} ${fmtDayMonth(b.startsAt).split(' ').last}, '
                    '${fmtTime(b.startsAt)} · '
                    '${b.isFreeTrial ? 'Free trial' : 'Paid'}',
                    style: AppText.small.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (live)
              const StatusBadge('Now', icon: AppIcons.clock)
            else if (b.status == BookingStatus.completed)
              const StatusBadge('Completed', tone: BadgeTone.neutral)
            else
              const Icon(
                AppIcons.chevronRight,
                size: 18,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

class _CoursesYouTeach extends StatelessWidget {
  const _CoursesYouTeach({required this.overview});

  final MentorOverview overview;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Courses you teach', style: AppText.h3),
      const SizedBox(height: Space.md),
      Wrap(
        spacing: Space.md,
        runSpacing: Space.md,
        children: [
          for (final c in overview.courses)
            SizedBox(
              width: 220,
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(c.courseName, style: AppText.bodyMedium),
                        ),
                        const StatusBadge('Verified', icon: AppIcons.verified),
                      ],
                    ),
                    Text(
                      '${formatRupiah(c.pricePerHour)}/hr',
                      style: AppText.small.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(
            width: 220,
            child: AppCard(
              dashed: true,
              color: AppColors.surface,
              onTap: () => context.push(Routes.mentorApply),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        AppIcons.plus,
                        size: 18,
                        color: AppColors.primaryPressed,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Add another course',
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyMedium.copyWith(
                            color: AppColors.primaryPressed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Upload a KHS showing an A or GPA 3.5+',
                    style: AppText.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

/// Mentor "Sessions" tab: every booking where I am the mentor.
class MentorSessionsScreen extends ConsumerWidget {
  const MentorSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(mentorBookingsProvider);
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(mentorBookingsProvider);
          await ref.read(mentorBookingsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.pageH,
            Space.xl,
            Space.pageH,
            Space.xxl,
          ),
          children: [
            Text('Sessions', style: AppText.h1),
            const SizedBox(height: Space.lg),
            ...list.when(
              loading: () => [const LoadingView()],
              error: (e, _) => [ErrorView(message: e.toString())],
              data: (all) {
                // Unpaid paid requests stay hidden until the learner pays.
                final visible = all
                    .where(
                      (m) =>
                          m.booking.status != BookingStatus.requested ||
                          m.isActionableRequest,
                    )
                    .map((m) => m.booking)
                    .toList();
                if (visible.isEmpty) {
                  return [
                    const EmptyView(
                      icon: AppIcons.calendar,
                      title: 'No sessions yet',
                    ),
                  ];
                }
                final now = DateTime.now();
                final current =
                    visible
                        .where(
                          (b) =>
                              b.endsAt.isAfter(now) &&
                              b.status != BookingStatus.declined &&
                              b.status != BookingStatus.cancelled,
                        )
                        .toList()
                      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
                final past = visible.where((b) => !current.contains(b)).toList()
                  ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
                return [
                  if (current.isNotEmpty) ...[
                    const SectionLabel('Upcoming and requests'),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                      child: Column(
                        children: [
                          for (final (i, b) in current.indexed) ...[
                            if (i > 0) const Divider(),
                            MentorSessionTile(booking: b),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (past.isNotEmpty) ...[
                    const SizedBox(height: Space.xl),
                    const SectionLabel('Past'),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                      child: Column(
                        children: [
                          for (final (i, b) in past.indexed) ...[
                            if (i > 0) const Divider(),
                            MentorSessionTile(booking: b),
                          ],
                        ],
                      ),
                    ),
                  ],
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}
