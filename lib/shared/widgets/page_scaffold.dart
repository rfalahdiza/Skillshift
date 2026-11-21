import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_button.dart';

/// Back button + title + optional "Step 1 of 2" (Figma `Navigation/Header`).
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.trailing,
    this.showBack = true,
    this.onBack,
  });

  final String title;
  final String? trailing;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.lg),
    child: Row(
      children: [
        if (showBack) ...[
          AppBackButton(onPressed: onBack),
          const SizedBox(width: Space.lg),
        ],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: AppText.h3.copyWith(fontSize: 17),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: AppText.smallMedium.copyWith(color: AppColors.textTertiary),
          ),
      ],
    ),
  );
}

/// Segmented step progress (two bars under the header).
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.current, required this.total});

  /// 1-based.
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Step $current of $total',
    child: Row(
      children: [
        for (var i = 1; i <= total; i++) ...[
          if (i > 1) const SizedBox(width: Space.sm),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i <= current ? AppColors.primary : AppColors.subtle,
                borderRadius: Radii.rFull,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// White footer pinned to the bottom with the primary action(s).
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.children, this.top});

  /// Buttons; two or more are laid out side by side.
  final List<Widget> children;

  /// Optional content above the buttons (e.g. "Total  Rp25.000").
  final Widget? top;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.pageH,
          Space.lg,
          Space.pageH,
          Space.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (top != null) ...[top!, const SizedBox(height: Space.md)],
            if (children.length == 1)
              children.first
            else
              Row(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: Space.md),
                    Expanded(child: children[i]),
                  ],
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

/// Standard full-screen page: cream canvas, scrollable body, max width on
/// larger screens, optional bottom action bar.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.body,
    this.header,
    this.bottom,
    this.maxWidth = 560,
    this.padding = const EdgeInsets.fromLTRB(
      Space.pageH,
      Space.sm,
      Space.pageH,
      Space.xxl,
    ),
  });

  final Widget? header;
  final List<Widget> body;
  final Widget? bottom;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: bottom == null,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(padding: padding, children: [?header, ...body]),
        ),
      ),
    ),
    bottomNavigationBar: bottom,
  );
}
