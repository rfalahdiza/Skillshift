import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_theme.dart';

/// Figma `Brand/Logo Mark`.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.height = 40});

  final double height;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/brand/logo_mark.svg',
    height: height,
    width: height * 0.75,
    semanticsLabel: 'SkillShift logo',
  );
}

/// Figma `Brand/Wordmark`: "SkillShift." in Inter ExtraBold, navy, teal dot.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.fontSize = 28});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppText.fontFamily,
      fontWeight: FontWeight.w800,
      fontSize: fontSize,
      height: 1.15,
      letterSpacing: -0.02 * fontSize,
      color: AppColors.navy,
    );
    return Text.rich(
      TextSpan(
        text: 'SkillShift',
        style: style,
        children: const [
          TextSpan(
            text: '.',
            style: TextStyle(color: AppColors.primary),
          ),
        ],
      ),
      semanticsLabel: 'SkillShift',
    );
  }
}

/// Logo mark + wordmark side by side (sidebar header).
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      LogoMark(height: size * 1.4),
      const SizedBox(width: Space.sm),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Wordmark(fontSize: size),
        ),
      ),
    ],
  );
}
