import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/time.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/surfaces.dart';
import 'home_screen.dart' show showComingSoon;

String _first(String name) => name.split(' ').first;

/// "Rp25.000 · held" and friends.
String paymentLabel(SessionDetail d) {
  final p = d.payment;
  if (d.booking.isFreeTrial) return 'Free trial';
  if (p == null) return '—';
  final status = switch (p.status) {
    'held' => 'held',
    'released' => 'released',
    'refunded' => 'refunded (sandbox)',
    'pending' => 'not paid yet',
    'expired' => 'expired',
    'failed' => 'failed',
    _ => p.status,
  };
  return '${formatRupiah(p.gross)} · $status';
}

/// L14 You're booked!
class BookingConfirmedScreen extends ConsumerWidget {
  const BookingConfirmedScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(sessionDetailProvider(bookingId));
    return detail.when(
      loading: () => const PageScaffold(body: [LoadingView()]),
      error: (e, _) => PageScaffold(body: [ErrorView(message: e.toString())]),
      data: (d) {
        final b = d.booking;
        final mentor = _first(d.mentorName);
        return PageScaffold(
          body: [
            const SizedBox(height: Space.xxxl),
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      AppIcons.check,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.xl),
            Text(
              'You’re booked!',
              textAlign: TextAlign.center,
              style: AppText.h1,
            ),
            const SizedBox(height: Space.sm),
            Text(
              b.status == BookingStatus.accepted
                  ? '$mentor accepted your session.'
                  : 'Payment received. Your request is waiting for $mentor '
                        'to accept.',
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: Space.xxl),
            AppCard(
              child: Column(
                children: [
                  KeyValueRow(
                    icon: AppIcons.book,
                    label: 'Course',
                    value: b.courseName,
                  ),
                  KeyValueRow(
                    icon: AppIcons.calendar,
                    label: 'When',
                    value: '${fmtDate(b.startsAt)}, ${fmtTime(b.startsAt)}',
                  ),
                  KeyValueRow(
                    icon: AppIcons.pin,
                    label: 'Where',
                    value: b.place,
                  ),
                  const Divider(height: Space.xl),
                  KeyValueRow(
                    icon: AppIcons.wallet,
                    label: 'Paid',
                    value: paymentLabel(d),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.lg),
            InfoBanner(
              tone: BannerTone.info,
              icon: AppIcons.info,
              text:
                  'Payment stays on hold until you and $mentor both tap '
                  '“Confirm attendance” after the session. If '
                  '$mentor declines, the payment is refunded (sandbox).',
            ),
            const SizedBox(height: Space.sm),
            const Center(child: StatusBadge.sandbox()),
          ],
          bottom: BottomActionBar(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label: 'View session',
                    onPressed: () =>
                        context.pushReplacement(Routes.learnerSession(b.id)),
                  ),
                  AppButton.text(
                    label: 'Back to home',
                    onPressed: () => context.go(Routes.learnerHome),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// L15 Session & attendance.
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref
        ..invalidate(sessionDetailProvider(widget.bookingId))
        ..invalidate(bookingsProvider);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCancel(SessionDetail d) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.pageH,
          0,
          Space.pageH,
          Space.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cancel this session?', style: AppText.h2),
            const SizedBox(height: Space.sm),
            Text(
              d.payment?.status == 'held'
                  ? 'Your payment will be refunded (sandbox, no real money).'
                  : 'The time slot will be free again.',
              style: AppText.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: Space.xl),
            AppButton(
              label: 'Cancel session',
              variant: AppButtonVariant.danger,
              onPressed: () => Navigator.pop(ctx, true),
            ),
            AppButton.text(
              label: 'Keep it',
              onPressed: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _run(
        () => ref.read(repositoryProvider).cancelBooking(d.booking.id),
        'Session cancelled.',
      );
    }
  }

  StatusBadge _statusBadge(SessionDetail d) {
    final b = d.booking;
    final other = _first(d.otherName);
    final ended = !DateTime.now().isBefore(b.endsAt);
    if (d.payment?.status == 'pending') {
      return const StatusBadge.pending(label: 'Waiting for payment');
    }
    return switch (b.status) {
      BookingStatus.requested when !d.iAmLearner => const StatusBadge(
        'New request · answer it on Home',
        tone: BadgeTone.info,
        icon: AppIcons.info,
      ),
      BookingStatus.requested => StatusBadge.pending(
        label: 'Waiting for $other to accept',
      ),
      BookingStatus.accepted when d.hasStarted && !d.iConfirmed => StatusBadge(
        ended
            ? 'Session ended · confirm attendance'
            : 'Session started · confirm attendance',
        icon: AppIcons.checkCircle,
      ),
      BookingStatus.accepted when d.hasStarted => StatusBadge(
        'Waiting for $other to confirm',
        tone: BadgeTone.warning,
        icon: AppIcons.clock,
      ),
      BookingStatus.accepted => StatusBadge(
        'Upcoming · ${fmtDayNum(b.startsAt)}',
        tone: BadgeTone.info,
        icon: AppIcons.calendar,
      ),
      BookingStatus.completed => const StatusBadge(
        'Completed',
        icon: AppIcons.verified,
      ),
      BookingStatus.declined => const StatusBadge.rejected(label: 'Declined'),
      BookingStatus.cancelled => const StatusBadge(
        'Cancelled',
        tone: BadgeTone.neutral,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(sessionDetailProvider(widget.bookingId));
    return detail.when(
      loading: () => const PageScaffold(
        header: PageHeader(title: 'Session'),
        body: [LoadingView()],
      ),
      error: (e, _) => PageScaffold(
        header: const PageHeader(title: 'Session'),
        body: [
          ErrorView(
            message: e.toString(),
            onRetry: () =>
                ref.invalidate(sessionDetailProvider(widget.bookingId)),
          ),
        ],
      ),
      data: (d) => _content(d),
    );
  }

  Widget _content(SessionDetail d) {
    final b = d.booking;
    final other = _first(d.otherName);
    final net = d.payment?.mentorNet;
    final fee = AppDefaults.platformFeePercent;

    final note = b.isFreeTrial
        ? 'Free trial: no payment. Confirm attendance after the session so it '
              'counts as completed.'
        : d.iAmLearner
        ? 'When both of you confirm, ${formatRupiah(net ?? 0)} goes to '
              '$other (after the $fee% platform fee, simulated payout). '
              'Something wrong? Report it within 24 hours.'
        : 'When both of you confirm, you receive ${formatRupiah(net ?? 0)} '
              '(simulated payout, no real money).';

    final actions = <Widget>[
      if (d.payment?.status == 'pending' && d.iAmLearner)
        AppButton(
          label: 'Complete payment',
          onPressed: () => context.push(Routes.learnerPay(b.id)),
        )
      else if (d.canConfirm)
        AppButton(
          label: 'Confirm attendance',
          loading: _busy,
          onPressed: () => _run(
            () => ref.read(repositoryProvider).confirmAttendance(b.id),
            'Attendance confirmed.',
          ),
        )
      else if (d.iConfirmed && b.status != BookingStatus.completed)
        AppButton(
          label: 'Waiting for $other',
          variant: AppButtonVariant.soft,
          onPressed: null,
        )
      else if (d.canCancel)
        AppButton.secondary(
          label: 'Cancel session',
          loading: _busy,
          onPressed: () => _confirmCancel(d),
        ),
      AppButton.text(
        label: 'Report a problem',
        onPressed: () => showComingSoon(context, 'Report a problem'),
      ),
    ];

    return PageScaffold(
      header: const PageHeader(title: 'Session'),
      body: [
        Align(alignment: Alignment.centerLeft, child: _statusBadge(d)),
        const SizedBox(height: Space.lg),
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  AppAvatar(name: d.otherName, size: 48),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${b.courseName} with $other', style: AppText.h3),
                        Text(
                          '${fmtDate(b.startsAt)} · ${fmtTime(b.startsAt)} '
                          'to ${fmtTime(b.endsAt)}',
                          style: AppText.small.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: Space.xl),
              KeyValueRow(icon: AppIcons.pin, label: 'Place', value: b.place),
              KeyValueRow(
                icon: AppIcons.wallet,
                label: 'Payment',
                value: paymentLabel(d),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        const SectionLabel('Attendance'),
        AppCard(
          child: Column(
            children: [
              _AttendanceRow(
                name: d.iAmLearner ? d.learnerName : d.mentorName,
                label: 'You',
                confirmedAt: d.confirmedAt[d.myUserId],
              ),
              const Divider(height: Space.xl),
              _AttendanceRow(
                name: d.otherName,
                label: d.otherName,
                confirmedAt: d.confirmedAt[d.otherId],
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        InfoBanner(
          tone: BannerTone.neutral,
          icon: AppIcons.verified,
          text: note,
        ),
        if (!b.isFreeTrial) ...[
          const SizedBox(height: Space.sm),
          const Center(child: StatusBadge.sandbox()),
        ],
      ],
      bottom: BottomActionBar(
        children: [Column(mainAxisSize: MainAxisSize.min, children: actions)],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.name,
    required this.label,
    required this.confirmedAt,
  });

  final String name;
  final String label;
  final DateTime? confirmedAt;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      AppAvatar(name: name, size: 40),
      const SizedBox(width: Space.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.bodyMedium),
            Text(
              confirmedAt == null
                  ? 'Waiting for confirmation'
                  : 'Confirmed at ${fmtTime(confirmedAt!)}',
              style: AppText.small.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      if (confirmedAt == null)
        const StatusBadge(
          'Waiting',
          tone: BadgeTone.warning,
          icon: AppIcons.clock,
        )
      else
        const StatusBadge('Confirmed', icon: AppIcons.verified),
    ],
  );
}
