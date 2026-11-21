import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/time.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/surfaces.dart';

/// What L11 hands to L12.
class CheckoutArgs {
  const CheckoutArgs({
    required this.request,
    required this.mentorName,
    required this.courseName,
    required this.pricePerHour,
  });

  final BookingRequest request;
  final String mentorName;
  final String courseName;
  final int pricePerHour;

  /// Display only. The server computes the real amount from the database.
  int get gross => (pricePerHour * request.durationMin / 60).round();
}

/// What L12 hands to L13.
class PaymentArgs {
  const PaymentArgs({required this.start, required this.method});

  final PaymentStart start;
  final PaymentMethod method;
}

/// L12 Review and pay (Midtrans SANDBOX).
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.args});

  final CheckoutArgs? args;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  PaymentMethod _method = PaymentMethod.qris;
  bool _agreed = false;
  bool _paying = false;
  String? _error;

  Future<void> _pay() async {
    final a = widget.args!;
    setState(() {
      _paying = true;
      _error = null;
    });
    final router = GoRouter.of(context);
    try {
      final start = await ref
          .read(repositoryProvider)
          .startPaidBooking(a.request, _method);
      ref.invalidate(bookingsProvider);
      router.pushReplacement(
        Routes.learnerPay(start.bookingId),
        extra: PaymentArgs(start: start, method: _method),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    if (a == null) {
      return PageScaffold(
        header: const PageHeader(title: 'Review and pay'),
        body: [
          EmptyView(
            icon: AppIcons.search,
            title: 'Start from a mentor',
            message: 'Pick a mentor and a time before paying.',
            action: 'Go to matches',
            onAction: () => context.go(Routes.learnerFind),
          ),
        ],
      );
    }
    final q = a.request;
    final first = a.mentorName.split(' ').first;
    final end = q.startsAt.add(Duration(minutes: q.durationMin));

    return PageScaffold(
      header: const PageHeader(title: 'Review and pay'),
      body: [
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  AppAvatar(name: a.mentorName, size: 48),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${a.courseName} with $first', style: AppText.h3),
                        Text(
                          'Paid session · ${q.durationMin} min',
                          style: AppText.small.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: Space.xxl),
              KeyValueRow(
                icon: AppIcons.calendar,
                label: 'Date',
                value: fmtDate(q.startsAt),
              ),
              KeyValueRow(
                icon: AppIcons.clock,
                label: 'Time',
                value: '${fmtTime(q.startsAt)} to ${fmtTime(end)}',
              ),
              KeyValueRow(icon: AppIcons.pin, label: 'Place', value: q.place),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        SectionLabel(
          'Pay with',
          trailing: const StatusBadge.sandbox(label: 'Sandbox · test payment'),
        ),
        for (final m in PaymentMethod.values) ...[
          _MethodCard(
            method: m,
            selected: m == _method,
            onTap: () => setState(() => _method = m),
          ),
          const SizedBox(height: Space.md),
        ],
        InfoBanner(
          text:
              'Your payment is held by SkillShift and released to $first only '
              'after you both confirm attendance.',
        ),
        const SizedBox(height: Space.lg),
        CheckRow(
          value: _agreed,
          onChanged: (v) => setState(() => _agreed = v),
          label:
              'I won’t ask my mentor to do graded assignments, quizzes, '
              'or exams for me.',
        ),
        if (_error != null) ...[
          const SizedBox(height: Space.lg),
          InfoBanner(tone: BannerTone.danger, text: _error!),
        ],
      ],
      bottom: BottomActionBar(
        top: Row(
          children: [
            Expanded(
              child: Text(
                'Total',
                style: AppText.body.copyWith(color: AppColors.textSecondary),
              ),
            ),
            Text(formatRupiah(a.gross), style: AppText.h2),
          ],
        ),
        children: [
          AppButton(
            label: 'Pay ${formatRupiah(a.gross)}',
            loading: _paying,
            onPressed: _agreed ? _pay : null,
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    selected: selected,
    color: AppColors.surface,
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.subtle,
            borderRadius: Radii.rMd,
          ),
          child: Icon(
            method == PaymentMethod.qris ? AppIcons.qr : AppIcons.card,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: Space.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(method.label, style: AppText.h3),
              Text(
                method.subtitle,
                style: AppText.small.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        RadioDot(selected: selected),
      ],
    ),
  );
}
