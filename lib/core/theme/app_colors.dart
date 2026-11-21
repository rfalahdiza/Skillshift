import 'package:flutter/material.dart';

/// Color tokens from the Figma `00 Design System` page.
abstract final class AppColors {
  // Brand
  static const primary = Color(0xFF20A298);
  static const primaryPressed = Color(0xFF178279);
  static const primarySoft = Color(0xFFE2F2EF);
  static const navy = Color(0xFF143956);
  static const navySoft = Color(0xFFE6EDF4);

  // Background
  static const canvas = Color(0xFFF4F2EC);
  static const surface = Color(0xFFFFFFFF);
  static const subtle = Color(0xFFECE9E1);

  // Text
  static const textPrimary = Color(0xFF13304A);
  static const textSecondary = Color(0xFF4D5B68);
  static const textTertiary = Color(0xFF8C96A0);
  static const textOnPrimary = Color(0xFFFFFFFF);

  // Border
  static const border = Color(0xFFE5E2D9);
  static const borderStrong = Color(0xFFD4D0C5);

  // Status
  static const warning = Color(0xFFB7791F);
  static const warningSoft = Color(0xFFFFF6E0);
  static const danger = Color(0xFFD93F44);
  static const dangerSoft = Color(0xFFFDECEC);
  static const info = Color(0xFF2F6FE4);
  static const infoSoft = Color(0xFFE8F0FD);
}

/// Avatar background/ink pairs.
enum AvatarTone {
  teal(Color(0xFFDDF0EC), Color(0xFF178279)),
  coral(Color(0xFFFFE4DA), Color(0xFFC4502F)),
  blue(Color(0xFFE3EAF3), Color(0xFF143956)),
  violet(Color(0xFFF1E6FA), Color(0xFF7E3FB0));

  const AvatarTone(this.background, this.ink);
  final Color background;
  final Color ink;

  /// Stable tone for a name or id, so a person keeps the same color.
  static AvatarTone forKey(String key) {
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return values[hash % values.length];
  }
}
