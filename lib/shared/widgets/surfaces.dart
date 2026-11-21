import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';

/// White card with a 1px border on the cream canvas (no shadow).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.lg),
    this.onTap,
    this.selected = false,
    this.color,
    this.radius = Radii.lg,
    this.dashed = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Selected cards get a teal border and teal-soft fill.
  final bool selected;
  final Color? color;
  final double radius;

  /// Dashed teal outline ("Free gap", "Add another course").
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final bg =
        color ??
        (selected || dashed ? AppColors.primarySoft : AppColors.surface);
    final side = selected
        ? const BorderSide(color: AppColors.primary, width: 1.5)
        : const BorderSide(color: AppColors.border);

    Widget content = Material(
      color: bg,
      shape: dashed
          ? RoundedRectangleBorder(borderRadius: borderRadius)
          : RoundedRectangleBorder(borderRadius: borderRadius, side: side),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );

    if (dashed) {
      content = CustomPaint(
        foregroundPainter: _DashedBorderPainter(radius: radius),
        child: content,
      );
    }
    return content;
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(0.6);
    final path = Path()..addRRect(rrect);
    const dash = 5.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.radius != radius;
}

/// Uppercase section label ("WHY THIS MATCH", "PAY WITH").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Row(
      children: [
        Expanded(child: Text(text.toUpperCase(), style: AppText.overline)),
        ?trailing,
      ],
    ),
  );
}

/// Section title with optional action link ("Your free gaps today · Edit").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.md),
    child: Row(
      children: [
        Expanded(child: Text(title, style: AppText.h3)),
        if (action != null)
          InkWell(
            onTap: onAction,
            borderRadius: Radii.rSm,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                action!,
                style: AppText.smallSemibold.copyWith(
                  color: AppColors.primaryPressed,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

enum BannerTone { primary, info, warning, danger, neutral }

/// Rounded soft-tinted note ("Payment stays on hold…", "Stored privately…").
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.text,
    this.tone = BannerTone.primary,
    this.icon,
  });

  final String text;
  final BannerTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, defaultIcon) = switch (tone) {
      BannerTone.primary => (
        AppColors.primarySoft,
        AppColors.primaryPressed,
        AppIcons.verified,
      ),
      BannerTone.info => (AppColors.infoSoft, AppColors.info, AppIcons.info),
      BannerTone.warning => (
        AppColors.warningSoft,
        AppColors.warning,
        AppIcons.warning,
      ),
      BannerTone.danger => (
        AppColors.dangerSoft,
        AppColors.danger,
        AppIcons.warning,
      ),
      BannerTone.neutral => (
        AppColors.subtle,
        AppColors.textSecondary,
        AppIcons.lock,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: bg, borderRadius: Radii.rMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, size: 18, color: fg),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(text, style: AppText.small.copyWith(color: fg)),
          ),
        ],
      ),
    );
  }
}

/// Sparkle + one-line AI reason on a subtle background (Card/Mentor Match).
class AiReason extends StatelessWidget {
  const AiReason(this.text, {super.key, this.highlighted = false});

  final String text;

  /// Teal-soft variant used on the mentor profile ("Why this match").
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(Space.md),
    decoration: BoxDecoration(
      color: highlighted ? AppColors.primarySoft : AppColors.subtle,
      borderRadius: Radii.rMd,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(AppIcons.sparkle, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Text(
            text,
            style: AppText.small.copyWith(
              color: highlighted
                  ? AppColors.primaryPressed
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Icon · label ........ value (booking summary rows).
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: Space.md),
        ],
        Text(
          label,
          style: AppText.small.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppText.smallSemibold,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
