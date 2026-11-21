import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import 'app_button.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.xxxl),
    child: Column(
      children: [
        const SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: Space.lg),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: AppText.small.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    ),
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.xxl),
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.subtle,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.textSecondary),
        ),
        const SizedBox(height: Space.lg),
        Text(title, style: AppText.h3, textAlign: TextAlign.center),
        if (message != null) ...[
          const SizedBox(height: Space.xs),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: AppText.small.copyWith(color: AppColors.textSecondary),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: Space.lg),
          AppButton.secondary(
            label: action!,
            expand: false,
            onPressed: onAction,
          ),
        ],
      ],
    ),
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyView(
    icon: AppIcons.warning,
    title: 'Something went wrong',
    message: message,
    action: onRetry == null ? null : 'Try again',
    onAction: onRetry,
  );
}
