import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/time.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/surfaces.dart';

/// M03 We're checking your KHS (or the rejection reason).
class MentorPendingScreen extends ConsumerWidget {
  const MentorPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(mentorOverviewProvider);
    return overview.when(
      loading: () => const PageScaffold(body: [LoadingView()]),
      error: (e, _) => PageScaffold(
        body: [
          ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(mentorOverviewProvider),
          ),
        ],
      ),
      data: (o) {
        final app = o.latestPending ?? o.applications.firstOrNull;
        if (app == null) {
          return PageScaffold(
            body: [
              EmptyView(
                icon: AppIcons.file,
                title: 'No application yet',
                action: 'Become a mentor',
                onAction: () => context.go(Routes.mentorApply),
              ),
            ],
          );
        }
        return _Body(app: app);
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.app});

  final MentorApplication app;

  @override
  Widget build(BuildContext context) {
    final rejected = app.status == ApplicationStatus.rejected;
    final approved = app.status == ApplicationStatus.approved;
    final (bg, fg, icon, title, body) = rejected
        ? (
            AppColors.dangerSoft,
            AppColors.danger,
            AppIcons.rejected,
            'Your application was not approved',
            'Read the reason below, then upload a clearer KHS or pick another '
                'course.',
          )
        : approved
        ? (
            AppColors.primarySoft,
            AppColors.primary,
            AppIcons.verified,
            'You’re a verified mentor',
            'You now appear in learners’ matches for ${app.courseName}.',
          )
        : (
            AppColors.warningSoft,
            AppColors.warning,
            AppIcons.clock,
            'We’re checking your KHS',
            'This usually takes less than a day. You will see the result on '
                'your mentor home.',
          );

    return PageScaffold(
      body: [
        const SizedBox(height: Space.xxxl),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: fg),
          ),
        ),
        const SizedBox(height: Space.xl),
        Text(title, textAlign: TextAlign.center, style: AppText.h1),
        const SizedBox(height: Space.sm),
        Text(
          body,
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Space.xxl),
        AppCard(
          child: Column(
            children: [
              _Step(
                state: _StepState.done,
                title: 'Application submitted',
                subtitle:
                    '${app.courseName} · ${formatRupiah(app.pricePerHour)}/hr '
                    '· ${fmtDayMonth(app.createdAt)}, ${fmtTime(app.createdAt)}',
              ),
              _Step(
                state: rejected
                    ? _StepState.failed
                    : approved
                    ? _StepState.done
                    : _StepState.current,
                title: 'Admin review',
                subtitle: rejected
                    ? 'Not approved'
                    : approved
                    ? 'Approved'
                    : app.proofType == 'gpa'
                    ? 'Checking your GPA on the KHS'
                    : 'Checking your grade on the KHS',
              ),
              _Step(
                state: approved ? _StepState.done : _StepState.todo,
                title: 'Start mentoring',
                subtitle: 'You’ll appear in learners’ matches',
                last: true,
              ),
            ],
          ),
        ),
        if (rejected && app.rejectReason != null) ...[
          const SizedBox(height: Space.lg),
          InfoBanner(
            tone: BannerTone.danger,
            icon: AppIcons.info,
            text: 'Reason from the admin: ${app.rejectReason}',
          ),
        ],
      ],
      bottom: BottomActionBar(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (rejected) ...[
                AppButton(
                  label: 'Apply again',
                  onPressed: () => context.go(Routes.mentorApply),
                ),
                const SizedBox(height: Space.sm),
              ],
              AppButton.secondary(
                label: 'Back to home',
                onPressed: () => context.go(Routes.mentorHome),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, current, failed, todo }

class _Step extends StatelessWidget {
  const _Step({
    required this.state,
    required this.title,
    required this.subtitle,
    this.last = false,
  });

  final _StepState state;
  final String title;
  final String subtitle;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (state) {
      _StepState.done => (AppColors.primary, Colors.white, AppIcons.check),
      _StepState.current => (
        AppColors.warningSoft,
        AppColors.warning,
        AppIcons.clock,
      ),
      _StepState.failed => (
        AppColors.dangerSoft,
        AppColors.danger,
        AppIcons.close,
      ),
      _StepState.todo => (AppColors.subtle, AppColors.textTertiary, null),
    };
    final muted = state == _StepState.todo;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: state == _StepState.current
                      ? Border.all(color: AppColors.warning, width: 1.5)
                      : null,
                ),
                child: icon == null
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.borderStrong,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : Icon(icon, size: 16, color: fg),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: state == _StepState.done
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : Space.xl, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.bodyMedium.copyWith(
                      color: muted
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppText.small.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
