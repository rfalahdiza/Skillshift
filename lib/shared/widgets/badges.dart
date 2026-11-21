import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

enum BadgeTone { success, warning, danger, info, neutral, onDark }

/// Figma `Badge`: small pill with optional leading icon.
class StatusBadge extends StatelessWidget {
  const StatusBadge(
    this.label, {
    super.key,
    this.tone = BadgeTone.success,
    this.icon,
  });

  /// "Pending", "Confirmed", ...
  final String label;
  final BadgeTone tone;
  final IconData? icon;

  const StatusBadge.pending({super.key, this.label = 'Pending'})
    : tone = BadgeTone.warning,
      icon = AppIcons.clock;
  const StatusBadge.approved({super.key, this.label = 'Approved'})
    : tone = BadgeTone.success,
      icon = AppIcons.verified;
  const StatusBadge.rejected({super.key, this.label = 'Rejected'})
    : tone = BadgeTone.danger,
      icon = AppIcons.rejected;
  const StatusBadge.needsCheck({super.key, this.label = 'Needs check'})
    : tone = BadgeTone.info,
      icon = AppIcons.info;

  /// Required on anything that shows simulated money (payouts, earnings).
  const StatusBadge.simulated({super.key, this.label = 'Simulated'})
    : tone = BadgeTone.warning,
      icon = null;

  /// Required next to every Midtrans payment surface.
  const StatusBadge.sandbox({
    super.key,
    this.label = 'Midtrans sandbox · test payment',
  }) : tone = BadgeTone.warning,
       icon = AppIcons.warning;

  /// Marks seeded or sample content.
  const StatusBadge.sample({super.key, this.label = 'SAMPLE'})
    : tone = BadgeTone.warning,
      icon = null;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeTone.success => (AppColors.primarySoft, AppColors.primaryPressed),
      BadgeTone.warning => (AppColors.warningSoft, AppColors.warning),
      BadgeTone.danger => (AppColors.dangerSoft, AppColors.danger),
      BadgeTone.info => (AppColors.infoSoft, AppColors.info),
      BadgeTone.neutral => (AppColors.subtle, AppColors.textSecondary),
      BadgeTone.onDark => (AppColors.surface, AppColors.primaryPressed),
    };
    final text = Text(
      label,
      style: AppText.caption.copyWith(color: fg),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: Radii.rFull),
      // Shrink the label with "…" only when the parent limits the width.
      child: LayoutBuilder(
        builder: (context, c) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 5),
            ],
            if (c.hasBoundedWidth) Flexible(child: text) else text,
          ],
        ),
      ),
    );
  }
}

/// Figma `Avatar`: initials on a tinted circle.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.size = 40, this.tone});

  final String name;
  final double size;

  /// Defaults to a stable tone derived from [name].
  final AvatarTone? tone;

  @override
  Widget build(BuildContext context) {
    final t = tone ?? AvatarTone.forKey(name);
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: t.background, shape: BoxShape.circle),
        child: Text(
          initialsOf(name),
          style: AppText.smallSemibold.copyWith(
            color: t.ink,
            fontSize: size * 0.36,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// "Coming soon" marker for planned features (never looks finished).
class ComingSoonBadge extends StatelessWidget {
  const ComingSoonBadge({super.key});

  @override
  Widget build(BuildContext context) =>
      const StatusBadge('Coming soon', tone: BadgeTone.neutral);
}
