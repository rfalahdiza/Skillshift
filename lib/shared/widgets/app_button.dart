import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';

enum AppButtonVariant {
  /// Teal fill, white text ("Get started", "Pay Rp25.000").
  primary,

  /// White fill, strong border, navy text ("Add class", "Decline").
  secondary,

  /// Teal-soft fill, teal text ("Waiting for Raka").
  soft,

  /// Danger-soft fill, red text ("Reject").
  dangerSoft,

  /// Red fill, white text ("Reject application").
  danger,

  /// No fill, teal text ("Back to home", "Cancel").
  text,
}

enum AppButtonSize { large, small }

/// Figma `Button`.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.large,
    this.icon,
    this.loading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.large,
    this.icon,
    this.loading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool loading;

  /// Fill the available width (default on phone footers).
  final bool expand;

  ({Color bg, Color fg, Color? border}) get _colors => switch (variant) {
    AppButtonVariant.primary => (
      bg: AppColors.primary,
      fg: AppColors.textOnPrimary,
      border: null,
    ),
    AppButtonVariant.secondary => (
      bg: AppColors.surface,
      fg: AppColors.textPrimary,
      border: AppColors.borderStrong,
    ),
    AppButtonVariant.soft => (
      bg: AppColors.primarySoft,
      fg: AppColors.primaryPressed,
      border: null,
    ),
    AppButtonVariant.dangerSoft => (
      bg: AppColors.dangerSoft,
      fg: AppColors.danger,
      border: null,
    ),
    AppButtonVariant.danger => (
      bg: AppColors.danger,
      fg: AppColors.textOnPrimary,
      border: null,
    ),
    AppButtonVariant.text => (
      bg: Colors.transparent,
      fg: AppColors.primaryPressed,
      border: null,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    final large = size == AppButtonSize.large;
    final disabled = onPressed == null || loading;
    final height = large ? 52.0 : 36.0;
    final textStyle = (large ? AppText.button : AppText.smallSemibold).copyWith(
      color: c.fg,
    );

    final child = loading
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: large ? 18 : 16, color: c.fg),
                const SizedBox(width: Space.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  style: textStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final button = Opacity(
      // Soft buttons are used as non-interactive status ("Waiting for Raka"),
      // drawn at full strength in the designs.
      opacity: disabled && !loading && variant != AppButtonVariant.soft
          ? 0.45
          : 1,
      child: Material(
        color: c.bg,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.rMd,
          side: c.border == null
              ? BorderSide.none
              : BorderSide(color: c.border!),
        ),
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: Radii.rMd,
          splashColor: variant == AppButtonVariant.primary
              ? AppColors.primaryPressed.withValues(alpha: 0.5)
              : null,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: large ? 20 : 14),
              child: Center(widthFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: !disabled,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

/// Square white back button used in page headers.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Back',
    child: Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.rMd,
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: Radii.rMd,
        onTap: onPressed ?? () => Navigator.of(context).maybePop(),
        child: const SizedBox.square(
          dimension: 44,
          child: Icon(AppIcons.back, size: 20, color: AppColors.textPrimary),
        ),
      ),
    ),
  );
}

/// Round white icon button (notification bell).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: AppColors.surface,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 48,
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    ),
  );
}
