import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time.dart';
import '../../data/models.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/surfaces.dart';

/// Status badge for an application (Pending / Needs check / Approved / ...).
Widget applicationBadge(AdminApplication a, {double minGpa = 3.5}) {
  if (a.needsCheck(minGpa)) return const StatusBadge.needsCheck();
  return switch (a.application.status) {
    ApplicationStatus.pending => const StatusBadge.pending(),
    ApplicationStatus.approved => const StatusBadge.approved(),
    ApplicationStatus.rejected => const StatusBadge.rejected(),
  };
}

/// "20 Nov" or "20 Nov, 14:05".
String shortDate(DateTime t, {bool time = false}) =>
    time ? '${fmtDayMonth(t)}, ${fmtTime(t)}' : fmtDayMonth(t);

/// "Rp450rb" for big dashboard numbers.
String compactRupiah(int amount) {
  if (amount >= 1000000) {
    final v = amount / 1000000;
    return 'Rp${v.toStringAsFixed(v >= 10 ? 0 : 1)}jt';
  }
  if (amount >= 1000) return 'Rp${(amount / 1000).round()}rb';
  return 'Rp$amount';
}

/// Dashboard stat card with an icon tile.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.tone,
    required this.value,
    required this.label,
    this.hint,
  });

  final IconData icon;
  final BadgeTone tone;
  final String value;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeTone.warning => (AppColors.warningSoft, AppColors.warning),
      BadgeTone.success => (AppColors.primarySoft, AppColors.primary),
      BadgeTone.info => (AppColors.infoSoft, AppColors.info),
      _ => (AppColors.subtle, AppColors.textSecondary),
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: bg, borderRadius: Radii.rSm),
            child: Icon(icon, size: 18, color: fg),
          ),
          const SizedBox(height: Space.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppText.h1),
          ),
          Text(
            label,
            style: AppText.small.copyWith(color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (hint != null)
            Text(
              hint!,
              style: AppText.caption.copyWith(color: AppColors.textTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

/// One application row (phone list).
class ApplicationTile extends StatelessWidget {
  const ApplicationTile({
    super.key,
    required this.app,
    required this.onTap,
    this.minGpa = 3.5,
  });

  final AdminApplication app;
  final VoidCallback onTap;
  final double minGpa;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Row(
        children: [
          AppAvatar(name: app.mentorName, size: 40),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.mentorName, style: AppText.bodyMedium),
                Text(
                  '${app.application.courseName} · ${app.proofLabel}',
                  style: AppText.small.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              applicationBadge(app, minGpa: minGpa),
              const SizedBox(height: 4),
              Text(
                shortDate(app.application.createdAt),
                style: AppText.caption.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Header row for wide admin tables.
class TableHeader extends StatelessWidget {
  const TableHeader({super.key, required this.columns, required this.flex});

  final List<String> columns;
  final List<int> flex;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 10),
    decoration: const BoxDecoration(
      color: AppColors.canvas,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        for (var i = 0; i < columns.length; i++)
          Expanded(
            flex: flex[i],
            child: Text(columns[i].toUpperCase(), style: AppText.overline),
          ),
      ],
    ),
  );
}

/// Icon for an activity item.
IconData activityIcon(ActivityKind k) => switch (k) {
  ActivityKind.paid => AppIcons.wallet,
  ActivityKind.released => AppIcons.checkCircle,
  ActivityKind.applied => AppIcons.file,
  ActivityKind.rejected => AppIcons.rejected,
  ActivityKind.approved => AppIcons.verified,
};

/// "2 min ago", "1 h ago", "yesterday", "20 Nov".
String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays == 1) return 'yesterday';
  return fmtDayMonth(t);
}
