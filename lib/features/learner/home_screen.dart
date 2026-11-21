import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_controller.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/gaps.dart';
import '../../core/utils/time.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/mentor_match_card.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/surfaces.dart';
import 'match_card_data.dart';

/// L08 Home (phone) / T01 (wide: matches panel on the right).
class LearnerHomeScreen extends ConsumerWidget {
  const LearnerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(sessionProvider).value?.firstName ?? '';
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref
            ..invalidate(bookingsProvider)
            ..invalidate(timetableProvider)
            ..invalidate(mentorCountsProvider);
          await ref.read(bookingsProvider.future);
        },
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 860;
            final main = <Widget>[
              _Header(name: name),
              const SizedBox(height: Space.xl),
              const _NextSessionCard(),
              const SizedBox(height: Space.xxl),
              const _FreeGaps(),
              const SizedBox(height: Space.xxl),
              const _StuckCard(),
              const SizedBox(height: Space.xxl),
              const _YourCourses(),
            ];
            if (!wide) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.pageH,
                  Space.xl,
                  Space.pageH,
                  Space.xxl,
                ),
                children: main,
              );
            }
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Space.xxl),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(children: main)),
                  const SizedBox(width: Space.xxl),
                  const SizedBox(width: 360, child: _TopMatchesPanel()),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting(),
              style: AppText.small.copyWith(color: AppColors.textSecondary),
            ),
            Text('Hi, $name', style: AppText.h1),
          ],
        ),
      ),
      AppIconButton(
        icon: AppIcons.bell,
        tooltip: 'Notifications',
        onPressed: () => showComingSoon(context, 'Notifications'),
      ),
    ],
  );
}

/// Small sheet for planned features (never looks finished).
void showComingSoon(BuildContext context, String feature) {
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.pageH,
        0,
        Space.pageH,
        Space.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(feature, style: AppText.h2)),
              const ComingSoonBadge(),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            'This is planned and not part of the prototype yet.',
            style: AppText.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: Space.xl),
          AppButton.secondary(label: 'OK', onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    ),
  );
}

class _NextSessionCard extends ConsumerWidget {
  const _NextSessionCard();

  String _when(DateTime startsAt) {
    final today = Wib.dateOnly(Wib.now());
    final day = Wib.dateOnly(Wib.toWall(startsAt));
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return fmtDayNum(startsAt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);
    final next = bookings.value?.where((b) => b.isUpcoming).firstOrNull;
    if (bookings.isLoading && next == null) return const SizedBox(height: 8);
    if (next == null) {
      return AppCard(
        child: Row(
          children: [
            const Icon(AppIcons.calendar, color: AppColors.textTertiary),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                'No sessions booked yet. Find a mentor to book your free trial.',
                style: AppText.small.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }
    final mentor = next.counterpartName ?? 'your mentor';
    final firstName = mentor.split(' ').first;
    return Material(
      color: AppColors.primary,
      borderRadius: Radii.rLg,
      child: InkWell(
        borderRadius: Radii.rLg,
        onTap: () => context.push(Routes.learnerSession(next.id)),
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'NEXT SESSION',
                      style: AppText.overline.copyWith(color: Colors.white70),
                    ),
                  ),
                  StatusBadge(
                    next.status == BookingStatus.requested
                        ? 'Waiting for $firstName'
                        : _when(next.startsAt),
                    tone: BadgeTone.onDark,
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              Row(
                children: [
                  AppAvatar(name: mentor, size: 44, tone: AvatarTone.coral),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${next.courseName} with $firstName',
                          style: AppText.h3.copyWith(
                            color: Colors.white,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          '${fmtSlot(next.startsAt, next.endsAt)} · ${next.place}',
                          style: AppText.small.copyWith(color: Colors.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreeGaps extends ConsumerWidget {
  const _FreeGaps();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = Wib.now();
    // On weekends show Monday's gaps.
    final isWeekend = now.weekday > 5;
    final day = isWeekend ? 1 : now.weekday;
    final title = isWeekend
        ? 'Your free gaps on Monday'
        : 'Your free gaps today';

    final entries = ref.watch(timetableProvider).value ?? const [];
    final bookings = ref.watch(bookingsProvider).value ?? const <Booking>[];
    final classes = entries
        .where((e) => e.dayOfWeek == day)
        .map((e) => e.range);
    final gaps = freeGaps(classes);

    // Bookings that fall on that date, in minutes since midnight (WIB).
    final targetDate = isWeekend
        ? Wib.dateOnly(now).add(Duration(days: 8 - now.weekday))
        : Wib.dateOnly(now);
    final booked = [
      for (final b in bookings.where((b) => b.isUpcoming))
        if (Wib.dateOnly(Wib.toWall(b.startsAt)) == targetDate)
          TimeRange(
            Wib.toWall(b.startsAt).hour * 60 + Wib.toWall(b.startsAt).minute,
            Wib.toWall(b.endsAt).hour * 60 + Wib.toWall(b.endsAt).minute,
          ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title,
          action: 'Edit timetable',
          onAction: () => context.go(Routes.learnerTimetable),
        ),
        if (entries.isEmpty)
          AppCard(
            child: Text(
              'Add your classes to see your free gaps.',
              style: AppText.small.copyWith(color: AppColors.textSecondary),
            ),
          )
        else if (gaps.isEmpty)
          AppCard(
            child: Text(
              'No free gaps of 30 minutes or more between 07:00 and 17:00.',
              style: AppText.small.copyWith(color: AppColors.textSecondary),
            ),
          )
        else
          Row(
            children: [
              for (final (i, g) in gaps.take(3).indexed) ...[
                if (i > 0) const SizedBox(width: Space.sm),
                Expanded(
                  child: _GapTile(
                    gap: g,
                    booked: booked.any(g.overlaps),
                    open: g.end == kDayEnd,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _GapTile extends StatelessWidget {
  const _GapTile({required this.gap, required this.booked, required this.open});

  final TimeRange gap;
  final bool booked;
  final bool open;

  @override
  Widget build(BuildContext context) => AppCard(
    selected: booked,
    radius: Radii.md,
    padding: const EdgeInsets.symmetric(
      horizontal: Space.md,
      vertical: Space.md,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hm(gap.start),
          style: AppText.h2.copyWith(
            color: booked ? AppColors.primaryPressed : AppColors.textPrimary,
          ),
        ),
        Text(
          booked
              ? 'Booked'
              : open
              ? 'Open'
              : '${gap.minutes} min',
          style: AppText.small.copyWith(
            color: booked ? AppColors.primaryPressed : AppColors.textTertiary,
          ),
        ),
      ],
    ),
  );
}

class _StuckCard extends StatelessWidget {
  const _StuckCard();

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(Space.xl),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.navySoft,
                borderRadius: Radii.rMd,
              ),
              child: const Icon(AppIcons.search, color: AppColors.navy),
            ),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stuck on a course?', style: AppText.h3),
                  Text(
                    'Get 3 mentor matches in under a minute.',
                    style: AppText.small.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        AppButton(
          label: 'Find a mentor',
          onPressed: () => context.push(Routes.learnerQuiz),
        ),
      ],
    ),
  );
}

class _YourCourses extends ConsumerWidget {
  const _YourCourses();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(coursesProvider).value ?? const <Course>[];
    final counts = ref.watch(mentorCountsProvider).value ?? const {};
    final names = {
      for (final e in ref.watch(timetableProvider).value ?? const [])
        e.courseName.toLowerCase(),
    };
    // Courses from the catalogue that appear in the learner's timetable.
    final mine = courses
        .where((c) => names.any((n) => n.startsWith(c.name.toLowerCase())))
        .toList();
    if (mine.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Your courses'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: Column(
            children: [
              for (final (i, c) in mine.indexed) ...[
                if (i > 0) const Divider(),
                InkWell(
                  onTap: () {
                    ref.read(selectedCourseProvider.notifier).select(c.id);
                    context.go(Routes.learnerFind);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.lg),
                    child: Row(
                      children: [
                        const Icon(
                          AppIcons.book,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Text(c.name, style: AppText.bodyMedium),
                        ),
                        Text(
                          '${counts[c.id] ?? 0} mentors',
                          style: AppText.small.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        const Icon(
                          AppIcons.chevronRight,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// T01 right column: current top matches, if the learner searched already.
class _TopMatchesPanel extends ConsumerWidget {
  const _TopMatchesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseId = ref.watch(selectedCourseProvider);
    if (courseId == null) {
      return AppCard(
        child: Text(
          'Your top mentor matches show up here after you answer three quick '
          'questions.',
          style: AppText.small.copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    final result = ref.watch(
      matchesProvider((courseId: courseId, maxPrice: null)),
    );
    return result.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (r) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'Top matches · ${r.course.name}',
            action: 'See all',
            onAction: () => context.go(Routes.learnerFind),
          ),
          for (final m in r.matches.take(2)) ...[
            MentorMatchCard(
              data: matchCardData(m, r.course.name),
              onTap: () => context.push(Routes.learnerMentor(m.mentorId)),
            ),
            const SizedBox(height: Space.md),
          ],
        ],
      ),
    );
  }
}
