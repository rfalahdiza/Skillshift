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
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/surfaces.dart';

/// Course name for the learner's current search.
String currentCourseName(WidgetRef ref) {
  final id = ref.read(selectedCourseProvider);
  final courses = ref.read(coursesProvider).value ?? const <Course>[];
  return courses.where((c) => c.id == id).firstOrNull?.name ?? 'this course';
}

/// L10 Mentor profile (phone, full screen).
class MentorProfileScreen extends ConsumerWidget {
  const MentorProfileScreen({super.key, required this.mentorId});

  final String mentorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = cachedMatch(ref, mentorId);
    if (match == null) return const _MatchMissing();
    return PageScaffold(
      header: const PageHeader(title: 'Mentor'),
      body: [
        MentorProfileBody(match: match, courseName: currentCourseName(ref)),
      ],
      bottom: BottomActionBar(
        children: [
          AppButton(
            label: 'Book a session',
            onPressed: () => context.push(Routes.learnerBook(mentorId)),
          ),
        ],
      ),
    );
  }
}

/// Shown when the screen is opened without match data (deep link, restart).
class _MatchMissing extends StatelessWidget {
  const _MatchMissing();

  @override
  Widget build(BuildContext context) => PageScaffold(
    header: const PageHeader(title: 'Mentor'),
    body: [
      EmptyView(
        icon: AppIcons.search,
        title: 'Open this mentor from your matches',
        message: 'Your matches need to be loaded first.',
        action: 'Go to matches',
        onAction: () => context.go(Routes.learnerFind),
      ),
    ],
  );
}

/// T02 right pane: the profile in a white card with actions at the bottom.
class MentorProfilePane extends StatelessWidget {
  const MentorProfilePane({
    super.key,
    required this.match,
    required this.courseName,
  });

  final MentorMatch match;
  final String courseName;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(Space.xxl),
    child: Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: MentorProfileBody(
              match: match,
              courseName: courseName,
              wide: true,
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(
              label: 'Book a session',
              expand: false,
              onPressed: () => context.push(Routes.learnerBook(match.mentorId)),
            ),
          ],
        ),
      ],
    ),
  );
}

class MentorProfileBody extends StatelessWidget {
  const MentorProfileBody({
    super.key,
    required this.match,
    required this.courseName,
    this.wide = false,
  });

  final MentorMatch match;
  final String courseName;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final m = match;
    final verified = StatusBadge(
      m.proofType == 'gpa' && m.gpa != null
          ? 'Verified: GPA ${m.gpa!.toStringAsFixed(2)}'
          : 'Verified: A in $courseName',
      icon: AppIcons.verified,
    );

    final identity = wide
        ? Row(
            children: [
              AppAvatar(name: m.fullName, size: 64),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.fullName, style: AppText.h1),
                    Text(
                      '${m.program} ${m.cohortYear}',
                      style: AppText.small.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    verified,
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${formatRupiah(m.pricePerHour)}/hr', style: AppText.h2),
                  if (m.freeTrialAvailable)
                    const StatusBadge('First 30 min free', icon: AppIcons.gift),
                ],
              ),
            ],
          )
        : Column(
            children: [
              AppAvatar(name: m.fullName, size: 80),
              const SizedBox(height: Space.md),
              Text(m.fullName, style: AppText.h1),
              const SizedBox(height: 2),
              Text(
                '${m.program} ${m.cohortYear}',
                style: AppText.small.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: Space.sm),
              verified,
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        identity,
        const SizedBox(height: Space.xl),
        _Stats(match: m, wide: wide),
        const SizedBox(height: Space.xl),
        const SectionLabel('Why this match'),
        AiReason(m.reason, highlighted: true),
        if (!m.reasonFromAi) ...[
          const SizedBox(height: 4),
          Text(
            'Standard summary (the AI reason was not available).',
            style: AppText.caption.copyWith(color: AppColors.textTertiary),
          ),
        ],
        const SizedBox(height: Space.xl),
        const SectionLabel('Teaches'),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final c
                in m.coursesTaught.isEmpty ? [courseName] : m.coursesTaught)
              AppChip(
                label: c,
                selected: c == courseName,
                style: ChipStyle.soft,
              ),
          ],
        ),
        const SizedBox(height: Space.xl),
        const SectionLabel('Shared free slots this week'),
        if (m.sharedSlots.isEmpty)
          Text(
            'No shared slot left this week.',
            style: AppText.small.copyWith(color: AppColors.textSecondary),
          )
        else
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final s in m.sharedSlots.take(6))
                SizedBox(
                  width: 112,
                  child: SlotTile(
                    label: '${fmtDayShort(s.startsAt)} ${fmtTime(s.startsAt)}',
                  ),
                ),
            ],
          ),
        if (m.bio != null && m.bio!.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          const SectionLabel('About'),
          Text(
            m.bio!,
            style: AppText.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.match, required this.wide});

  final MentorMatch match;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final m = match;
    final cells = <(String, String)>[
      (m.gpa?.toStringAsFixed(2) ?? '—', 'GPA'),
      if (wide)
        (m.proofType == 'gpa' ? 'GPA' : 'A', 'Proof')
      else
        (formatRupiah(m.pricePerHour), 'per hour'),
      if (wide)
        ('${m.sharedSlots.length}', 'shared gaps')
      else if (m.freeTrialAvailable)
        ('30 min', 'free first')
      else
        ('Used', 'free trial'),
    ];
    return AppCard(
      color: wide ? AppColors.canvas : null,
      padding: const EdgeInsets.symmetric(vertical: Space.lg),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (final (i, c) in cells.indexed) ...[
              if (i > 0) const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    Text(c.$1, style: AppText.h2),
                    Text(
                      c.$2,
                      style: AppText.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
