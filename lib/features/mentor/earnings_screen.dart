import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/time.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/surfaces.dart';

/// M05 Earnings. Payouts are SIMULATED (database records only) and the
/// screen says so in several places.
class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  void _withdraw(BuildContext context) => showModalBottomSheet<void>(
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
          Row(
            children: [
              Expanded(child: Text('Withdraw', style: AppText.h2)),
              const StatusBadge.simulated(),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Payouts are simulated in this prototype. Released amounts are '
            'recorded in the database, but no bank transfer is made.',
            style: AppText.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: Space.xl),
          AppButton.secondary(label: 'OK', onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnings = ref.watch(earningsProvider);
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(earningsProvider);
          await ref.read(earningsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.pageH,
            Space.xl,
            Space.pageH,
            Space.xxl,
          ),
          children: [
            Text('Earnings', style: AppText.h1),
            const SizedBox(height: Space.lg),
            const InfoBanner(
              tone: BannerTone.warning,
              text:
                  'Payouts are simulated in this prototype. No real money is '
                  'transferred yet.',
            ),
            const SizedBox(height: Space.lg),
            ...earnings.when(
              loading: () => [const LoadingView()],
              error: (e, _) => [
                ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(earningsProvider),
                ),
              ],
              data: (e) => [
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: 'Available',
                        value: formatRupiah(e.available),
                        hint: 'Released after both confirmed',
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: _Stat(
                        label: 'On hold',
                        value: formatRupiah(e.onHold),
                        hint: 'Waiting for attendance',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                AppButton(
                  label: 'Withdraw (simulated)',
                  onPressed: () => _withdraw(context),
                ),
                const SizedBox(height: Space.xxl),
                Row(
                  children: [
                    Expanded(child: Text('History', style: AppText.h3)),
                    Text(
                      'Platform fee ${e.feePercent}%',
                      style: AppText.small.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                if (e.lines.isEmpty)
                  AppCard(
                    child: Text(
                      'No paid sessions yet. Free trials do not earn money.',
                      style: AppText.small.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: Column(
                      children: [
                        for (final (i, l) in e.lines.indexed) ...[
                          if (i > 0) const Divider(),
                          _Line(line: l),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.hint});

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.small.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Space.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AppText.h2.copyWith(fontSize: 20)),
        ),
        Text(
          hint,
          style: AppText.caption.copyWith(color: AppColors.textTertiary),
        ),
      ],
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.line});

  final EarningLine line;

  @override
  Widget build(BuildContext context) {
    final l = line;
    final released = l.status == 'released';
    final parts = l.learnerName.split(' ');
    final short = parts.length > 1
        ? '${parts[0]} ${parts[1][0]}.'
        : l.learnerName;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Row(
        children: [
          AppAvatar(name: l.learnerName, size: 40),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$short · ${l.courseName}', style: AppText.bodyMedium),
                Text(
                  fmtDate(l.startsAt),
                  style: AppText.small.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                released ? '+${formatRupiah(l.net)}' : formatRupiah(l.net),
                style: AppText.smallSemibold.copyWith(
                  fontSize: 14,
                  color: released
                      ? AppColors.primaryPressed
                      : AppColors.textSecondary,
                ),
              ),
              Text(
                released ? 'from ${formatRupiah(l.gross)}' : 'On hold',
                style: AppText.caption.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
