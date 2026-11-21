import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Text styles from the Figma `Typography · Inter` frame.
abstract final class AppText {
  static const fontFamily = 'Inter';

  static TextStyle _s(
    double size,
    double lineHeight,
    FontWeight weight, {
    double spacing = 0,
    Color color = AppColors.textPrimary,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    letterSpacing: spacing,
    color: color,
  );

  static final display = _s(28, 34, FontWeight.w700);
  static final h1 = _s(24, 30, FontWeight.w700);
  static final h2 = _s(18, 24, FontWeight.w600);
  static final h3 = _s(16, 22, FontWeight.w600);
  static final body = _s(15, 22, FontWeight.w400);
  static final bodyMedium = _s(15, 22, FontWeight.w500);
  static final small = _s(13, 18, FontWeight.w400);
  static final smallMedium = _s(13, 18, FontWeight.w500);
  static final smallSemibold = _s(13, 18, FontWeight.w600);
  static final caption = _s(12, 16, FontWeight.w500);

  /// Render with `.toUpperCase()` text; style alone does not change case.
  static final overline = _s(
    11,
    14,
    FontWeight.w600,
    spacing: 0.6,
    color: AppColors.textTertiary,
  );
  static final button = _s(15, 20, FontWeight.w600);
  static final amount = _s(32, 38, FontWeight.w700);
}
