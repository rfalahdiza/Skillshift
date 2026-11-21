import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/brand.dart';

/// L01 Splash. The router leaves this screen once the session is restored.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const Spacer(),
          const LogoMark(height: 72),
          const SizedBox(height: Space.xxl),
          const Wordmark(fontSize: 30),
          const SizedBox(height: Space.sm),
          Text(
            'Peer learning for UB students',
            style: AppText.body.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xxl),
            child: Text(
              'Universitas Brawijaya',
              style: AppText.caption.copyWith(color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    ),
  );
}
