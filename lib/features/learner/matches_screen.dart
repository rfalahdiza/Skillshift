import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/mentor_match_card.dart';
import '../../shared/widgets/state_views.dart';
import 'match_card_data.dart';
import 'mentor_profile_screen.dart';

const _kPriceCap = 30000;

/// L09 Top 3 mentors (phone) / T02 list + profile (wide).
class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});

  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen> {
  /// Selected mentor in the wide two-pane layout.
  String? _selected;

  Future<void> _changeCourse(List<Course> courses, String current) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: Space.lg),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.pageH,
                0,
                Space.pageH,
                Space.md,
              ),
              child: Text('Choose a course', style: AppText.h2),
            ),
            for (final c in courses)
              ListTile(
                title: Text(c.name, style: AppText.bodyMedium),
                trailing: c.id == current
                    ? const Icon(AppIcons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, c.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == current || !mounted) return;
    final pref = await ref.read(preferenceProvider(picked).future);
    ref.read(selectedCourseProvider.notifier).select(picked);
    setState(() => _selected = null);
    // No answers for that course yet: ask the quick questions first.
    if (pref == null && mounted) context.push(Routes.learnerQuiz);
  }

  @override
  Widget build(BuildContext context) {
    final courseId = ref.watch(selectedCourseProvider);
    if (courseId == null) {
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.pageH),
          children: [
            Text('Find a mentor', style: AppText.display),
            EmptyView(
              icon: AppIcons.search,
              title: 'Tell us what you need',
              message:
                  'Answer three quick questions and we will match you with '
                  'three verified seniors who share your free gaps.',
              action: 'Start',
              onAction: () => context.push(Routes.learnerQuiz),
            ),
          ],
        ),
      );
    }

    final cap = ref.watch(priceCapProvider);
    final query = (courseId: courseId, maxPrice: cap);
    final result = ref.watch(matchesProvider(query));
    final courses = ref.watch(coursesProvider).value ?? const <Course>[];
    final courseName =
        result.value?.course.name ??
        courses.where((c) => c.id == courseId).firstOrNull?.name ??
        'your course';

    final header = <Widget>[
      Text('Top 3 mentors', style: AppText.h1),
      const SizedBox(height: Space.xs),
      Text(
        'For $courseName, matched to your timetable and how you like to learn.',
        style: AppText.small.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: Space.md),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            AppChip(
              label: courseName,
              selected: true,
              style: ChipStyle.soft,
              onTap: () => _changeCourse(courses, courseId),
            ),
            const SizedBox(width: Space.sm),
            const AppChip(label: 'This week'),
            const SizedBox(width: Space.sm),
            AppChip(
              label: 'Under Rp30.000',
              selected: cap != null,
              style: ChipStyle.soft,
              onTap: () {
                ref.read(priceCapProvider.notifier).toggle(_kPriceCap);
                setState(() => _selected = null);
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: Space.sm),
      Row(
        children: [
          const Icon(AppIcons.sparkle, size: 13, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Match reasons are written by AI from your answers.',
              style: AppText.caption.copyWith(color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
      const SizedBox(height: Space.lg),
    ];

    Widget list(bool wide, MatchResult r) {
      if (r.matches.isEmpty) {
        return EmptyView(
          icon: AppIcons.calendar,
          title: 'No shared free gap this week',
          message: cap != null
              ? 'No match under Rp30.000. Remove the price filter to see more.'
              : 'None of the verified mentors for $courseName is free when you '
                    'are. Check that your timetable is complete.',
          action: 'Edit timetable',
          onAction: () => context.go(Routes.learnerTimetable),
        );
      }
      final selected = _selected ?? r.matches.first.mentorId;
      return Column(
        children: [
          for (final m in r.matches) ...[
            MentorMatchCard(
              data: matchCardData(m, r.course.name),
              selected: wide && m.mentorId == selected,
              onTap: () => wide
                  ? setState(() => _selected = m.mentorId)
                  : context.push(Routes.learnerMentor(m.mentorId)),
            ),
            const SizedBox(height: Space.md),
          ],
        ],
      );
    }

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 860;
          final body = result.when(
            loading: () => const LoadingView(
              message: 'Finding mentors who share your free gaps…',
            ),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(matchesProvider(query)),
            ),
            data: (r) => list(wide, r),
          );

          final listPane = RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(matchesProvider(query));
              await ref.read(matchesProvider(query).future);
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                wide ? Space.xxl : Space.pageH,
                Space.xl,
                wide ? Space.lg : Space.pageH,
                Space.xxl,
              ),
              children: [...header, body],
            ),
          );
          if (!wide) return listPane;

          final r = result.value;
          final selectedMatch = r == null || r.matches.isEmpty
              ? null
              : r.matches.firstWhere(
                  (m) => m.mentorId == _selected,
                  orElse: () => r.matches.first,
                );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 420, child: listPane),
              Expanded(
                child: selectedMatch == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.sm,
                          Space.xl,
                          Space.xxl,
                          Space.xl,
                        ),
                        child: MentorProfilePane(
                          match: selectedMatch,
                          courseName: r!.course.name,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
