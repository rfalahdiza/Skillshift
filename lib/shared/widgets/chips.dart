import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum ChipStyle {
  /// Selected = teal fill / white text; unselected = white with border.
  choice,

  /// Teal-soft fill / teal text (selected filter, taught course).
  soft,
}

/// Figma `Chip`.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.style = ChipStyle.choice,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final ChipStyle style;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = !enabled
        ? (AppColors.subtle, AppColors.textTertiary, AppColors.subtle)
        : switch ((style, selected)) {
            (ChipStyle.choice, true) => (
              AppColors.primary,
              AppColors.textOnPrimary,
              AppColors.primary,
            ),
            (ChipStyle.soft, true) => (
              AppColors.primarySoft,
              AppColors.primaryPressed,
              AppColors.primarySoft,
            ),
            (_, false) => (
              AppColors.surface,
              AppColors.textPrimary,
              AppColors.border,
            ),
          };
    return Semantics(
      button: onTap != null,
      selected: selected,
      enabled: enabled,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: BorderSide(color: border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Text(label, style: AppText.smallMedium.copyWith(color: fg)),
          ),
        ),
      ),
    );
  }
}

/// Rounded-rect time slot tile ("12:00", disabled "13:00").
class SlotTile extends StatelessWidget {
  const SlotTile({
    super.key,
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = !enabled
        ? (AppColors.subtle, AppColors.textTertiary, AppColors.subtle)
        : selected
        ? (AppColors.primary, AppColors.textOnPrimary, AppColors.primary)
        : (AppColors.surface, AppColors.textPrimary, AppColors.border);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.rMd,
          side: BorderSide(color: border),
        ),
        child: InkWell(
          borderRadius: Radii.rMd,
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(
                label,
                style: AppText.smallSemibold.copyWith(color: fg, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
