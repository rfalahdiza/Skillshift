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
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/surfaces.dart';
import 'checkout_screen.dart';
import 'mentor_profile_screen.dart';

/// Start times (every 30 min) inside the shared gaps on one WIB date.
/// A start is enabled when the whole session fits in its gap.
List<({DateTime start, bool fits})> slotStarts(
  List<Slot> gaps,
  DateTime wibDate,
  int durationMin,
) {
  final out = <({DateTime start, bool fits})>[];
  for (final g in gaps) {
    if (Wib.dateOnly(Wib.toWall(g.startsAt)) != wibDate) continue;
    // Round the gap start up to the next :00 or :30.
    var t = g.startsAt;
    final wall = Wib.toWall(t);
    final rem = wall.minute % 30;
    if (rem != 0) t = t.add(Duration(minutes: 30 - rem));
    while (!t.add(const Duration(minutes: 30)).isAfter(g.endsAt)) {
      final fits = !t.add(Duration(minutes: durationMin)).isAfter(g.endsAt);
      out.add((start: t, fits: fits));
      t = t.add(const Duration(minutes: 30));
    }
  }
  return out;
}

/// L11 Book with a mentor.
class BookSessionScreen extends ConsumerStatefulWidget {
  const BookSessionScreen({super.key, required this.mentorId});

  final String mentorId;

  @override
  ConsumerState<BookSessionScreen> createState() => _BookSessionScreenState();
}

class _BookSessionScreenState extends ConsumerState<BookSessionScreen> {
  MentorMatch? _match;
  late bool _trial;
  DateTime? _date; // WIB date
  DateTime? _start; // instant
  CampusPlace _place = kCampusPlaces.first;
  bool _sending = false;

  int get _duration => _trial ? 30 : 60;

  @override
  void initState() {
    super.initState();
    _match = cachedMatch(ref, widget.mentorId);
    _trial = _match?.freeTrialAvailable ?? false;
    final first = _match?.sharedSlots.firstOrNull;
    if (first != null) _date = Wib.dateOnly(Wib.toWall(first.startsAt));
    _pickFirstFittingStart();
  }

  void _pickFirstFittingStart() {
    final m = _match;
    if (m == null || _date == null) return;
    final starts = slotStarts(m.sharedSlots, _date!, _duration);
    final keep = starts.where((s) => s.fits && s.start == _start).firstOrNull;
    _start = keep?.start ?? starts.where((s) => s.fits).firstOrNull?.start;
  }

  Future<void> _review() async {
    final m = _match!;
    if (_start == null) return;
    if (!_trial) {
      // Paid sessions go through checkout (L12).
      context.push(
        Routes.learnerCheckout,
        extra: CheckoutArgs(
          request: BookingRequest(
            mentorId: m.mentorId,
            courseId: ref.read(selectedCourseProvider)!,
            startsAt: _start!,
            durationMin: _duration,
            place: _place.name,
            isFreeTrial: false,
          ),
          mentorName: m.fullName,
          courseName: currentCourseName(ref),
          pricePerHour: m.pricePerHour,
        ),
      );
      return;
    }
    final courseName = currentCourseName(ref);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SingleChildScrollView(
        child: Padding(
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
              Text('Send a free trial request?', style: AppText.h2),
              const SizedBox(height: Space.lg),
              KeyValueRow(
                icon: AppIcons.book,
                label: 'Course',
                value: courseName,
              ),
              KeyValueRow(
                icon: AppIcons.user,
                label: 'Mentor',
                value: m.fullName,
              ),
              KeyValueRow(
                icon: AppIcons.calendar,
                label: 'When',
                value: fmtSlot(
                  _start!,
                  _start!.add(Duration(minutes: _duration)),
                ),
              ),
              KeyValueRow(
                icon: AppIcons.pin,
                label: 'Where',
                value: _place.name,
              ),
              const KeyValueRow(
                icon: AppIcons.gift,
                label: 'Price',
                value: 'Free trial · Rp0',
              ),
              const SizedBox(height: Space.lg),
              InfoBanner(
                tone: BannerTone.info,
                text:
                    '${m.fullName.split(' ').first} will accept or decline. '
                    'Mentors never do graded work for you.',
              ),
              const SizedBox(height: Space.xl),
              AppButton(
                label: 'Send request',
                onPressed: () => Navigator.pop(ctx, true),
              ),
              AppButton.text(
                label: 'Cancel',
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _sending = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(repositoryProvider)
          .requestBooking(
            BookingRequest(
              mentorId: m.mentorId,
              courseId: ref.read(selectedCourseProvider)!,
              startsAt: _start!,
              durationMin: _duration,
              place: _place.name,
              isFreeTrial: true,
            ),
          );
      ref
        ..invalidate(bookingsProvider)
        ..invalidate(matchesProvider);
      router.go(Routes.learnerSessions);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Request sent to ${m.fullName.split(' ').first}.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _match;
    if (m == null) {
      return MentorProfileScreen(mentorId: widget.mentorId);
    }
    final first = m.fullName.split(' ').first;
    final dates = <DateTime>{
      for (final s in m.sharedSlots) Wib.dateOnly(Wib.toWall(s.startsAt)),
    }.toList()..sort();
    final starts = _date == null
        ? const <({DateTime start, bool fits})>[]
        : slotStarts(m.sharedSlots, _date!, _duration);

    final form = <Widget>[
      const SectionLabel('Session type'),
      Row(
        children: [
          Expanded(
            child: _TypeCard(
              title: 'Free trial · 30 min',
              subtitle: m.freeTrialAvailable
                  ? 'Rp0 · first session'
                  : m.freeTrialUsedOn == null
                  ? 'Already used'
                  : 'Used on ${fmtDayMonth(m.freeTrialUsedOn!)}',
              selected: _trial,
              enabled: m.freeTrialAvailable,
              onTap: () => setState(() {
                _trial = true;
                _pickFirstFittingStart();
              }),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: _TypeCard(
              title: 'Paid · 60 min',
              subtitle: formatRupiah(m.pricePerHour),
              selected: !_trial,
              onTap: () => setState(() {
                _trial = false;
                _pickFirstFittingStart();
              }),
            ),
          ),
        ],
      ),
      const SizedBox(height: Space.xl),
      const SectionLabel('Date'),
      if (dates.isEmpty)
        Text(
          'No shared free slot left this week.',
          style: AppText.small.copyWith(color: AppColors.textSecondary),
        )
      else
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final d in dates)
              AppChip(
                label: fmtDayNum(Wib.fromWall(d)),
                selected: d == _date,
                onTap: () => setState(() {
                  _date = d;
                  _start = null;
                  _pickFirstFittingStart();
                }),
              ),
          ],
        ),
      const SizedBox(height: Space.xl),
      SectionLabel(
        'Time',
        trailing: Text(
          'Shared gaps only',
          style: AppText.caption.copyWith(color: AppColors.textTertiary),
        ),
      ),
      if (starts.isEmpty)
        Text(
          'Pick a date first.',
          style: AppText.small.copyWith(color: AppColors.textSecondary),
        )
      else
        GridView.extent(
          maxCrossAxisExtent: 140, // ~3 columns on phones, more on tablets
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Space.sm,
          crossAxisSpacing: Space.sm,
          childAspectRatio: 2.6,
          children: [
            for (final s in starts)
              SlotTile(
                label: fmtTime(s.start),
                selected: s.start == _start,
                enabled: s.fits,
                onTap: () => setState(() => _start = s.start),
              ),
          ],
        ),
      const SizedBox(height: Space.xl),
      const SectionLabel('Meet on campus'),
      for (final p in kCampusPlaces) ...[
        _PlaceCard(
          place: p,
          selected: p == _place,
          onTap: () => setState(() => _place = p),
        ),
        const SizedBox(height: Space.md),
      ],
      const InfoBanner(
        tone: BannerTone.info,
        text:
            'Sessions happen in person on campus. After the session you both '
            'confirm attendance in the app.',
      ),
    ];

    final phone = PageScaffold(
      header: PageHeader(title: 'Book with $first'),
      body: form,
      bottom: BottomActionBar(
        children: [
          AppButton(
            label: _trial ? 'Review booking' : 'Review and pay',
            loading: _sending,
            onPressed: _start == null ? null : _review,
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, c) => c.maxWidth < 860 ? phone : _wide(m, form, first),
    );
  }

  /// T04: form on the left; summary and payment on the right.
  Widget _wide(MentorMatch m, List<Widget> form, String first) {
    final courseName = currentCourseName(ref);
    final end = _start?.add(Duration(minutes: _duration));
    final gross = _trial ? 0 : (m.pricePerHour * _duration / 60).round();
    final summary = AppCard(
      child: Column(
        children: [
          Row(
            children: [
              AppAvatar(name: m.fullName, size: 44),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$courseName with $first', style: AppText.h3),
                    Text(
                      _trial
                          ? 'Free trial · 30 min'
                          : 'Paid session · $_duration min',
                      style: AppText.small.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: Space.xl),
          KeyValueRow(
            icon: AppIcons.calendar,
            label: 'Date',
            value: _start == null ? '—' : fmtDate(_start!),
          ),
          KeyValueRow(
            icon: AppIcons.clock,
            label: 'Time',
            value: _start == null
                ? '—'
                : '${fmtTime(_start!)} to ${fmtTime(end!)}',
          ),
          KeyValueRow(icon: AppIcons.pin, label: 'Place', value: _place.name),
          const Divider(height: Space.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: AppText.body.copyWith(color: AppColors.textSecondary),
                ),
              ),
              Text(_trial ? 'Free' : formatRupiah(gross), style: AppText.h2),
            ],
          ),
        ],
      ),
    );

    final right = <Widget>[
      summary,
      const SizedBox(height: Space.xl),
      if (_start == null)
        Text(
          'Pick a date and time to continue.',
          style: AppText.small.copyWith(color: AppColors.textSecondary),
        )
      else if (_trial)
        AppButton(
          label: 'Send free trial request',
          loading: _sending,
          onPressed: _review,
        )
      else
        PayPanel(
          // New key per slot so a changed time starts a fresh payment form.
          key: ValueKey('$_start|${_place.name}'),
          args: CheckoutArgs(
            request: BookingRequest(
              mentorId: m.mentorId,
              courseId: ref.read(selectedCourseProvider)!,
              startsAt: _start!,
              durationMin: _duration,
              place: _place.name,
              isFreeTrial: false,
            ),
            mentorName: m.fullName,
            courseName: courseName,
            pricePerHour: m.pricePerHour,
          ),
        ),
    ];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: Space.lg),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Book with $first', style: AppText.h1),
                      Text(
                        '$courseName · ${_trial ? 'free trial' : 'paid session'}',
                        style: AppText.small.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Space.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(Space.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: form,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.xl),
                  SizedBox(
                    width: 400,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: right,
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

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = !enabled
        ? AppColors.textTertiary
        : selected
        ? AppColors.primaryPressed
        : AppColors.textPrimary;
    return Semantics(
      selected: selected,
      enabled: enabled,
      button: true,
      child: AppCard(
        selected: selected && enabled,
        color: enabled ? null : AppColors.subtle,
        radius: Radii.md,
        padding: const EdgeInsets.all(Space.lg),
        onTap: enabled ? onTap : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppText.smallSemibold.copyWith(color: fg, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: AppText.caption.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.selected,
    required this.onTap,
  });

  final CampusPlace place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    selected: selected,
    color: AppColors.surface,
    radius: Radii.lg,
    onTap: onTap,
    padding: const EdgeInsets.all(Space.lg),
    child: Row(
      children: [
        Icon(
          AppIcons.pin,
          color: selected ? AppColors.primary : AppColors.textSecondary,
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(place.name, style: AppText.bodyMedium),
              Text(
                place.note,
                style: AppText.small.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        RadioDot(selected: selected),
      ],
    ),
  );
}

/// Learner "Sessions" tab: list of requests and sessions. Attendance and
/// session detail (L15) arrive in Phase 3.
class LearnerSessionsScreen extends ConsumerWidget {
  const LearnerSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(bookingsProvider);
          await ref.read(bookingsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.pageH,
            Space.xl,
            Space.pageH,
            Space.xxl,
          ),
          children: [
            Text('Sessions', style: AppText.h1),
            const SizedBox(height: Space.lg),
            ...bookings.when(
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (e, _) => [Text(e.toString())],
              data: (list) {
                if (list.isEmpty) {
                  return [
                    Text(
                      'No sessions yet. Find a mentor to book your free trial.',
                      style: AppText.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ];
                }
                final upcoming = list.where((b) => b.isUpcoming).toList();
                final past = list.where((b) => !b.isUpcoming).toList().reversed;
                return [
                  if (upcoming.isNotEmpty) ...[
                    const SectionLabel('Upcoming'),
                    for (final b in upcoming) _BookingTile(booking: b),
                  ],
                  if (past.isNotEmpty) ...[
                    const SizedBox(height: Space.lg),
                    const SectionLabel('Past'),
                    for (final b in past) _BookingTile(booking: b),
                  ],
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final badge = switch (b.status) {
      BookingStatus.requested => const StatusBadge.pending(label: 'Requested'),
      BookingStatus.accepted => const StatusBadge(
        'Accepted',
        icon: AppIcons.verified,
      ),
      BookingStatus.completed => const StatusBadge(
        'Completed',
        tone: BadgeTone.neutral,
      ),
      BookingStatus.declined => const StatusBadge.rejected(label: 'Declined'),
      BookingStatus.cancelled => const StatusBadge(
        'Cancelled',
        tone: BadgeTone.neutral,
      ),
    };
    final price = b.isFreeTrial
        ? 'Free trial'
        : b.gross == null
        ? 'Paid'
        : '${formatRupiah(b.gross!)}${b.paymentStatus == 'held' ? ' · held' : ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: AppCard(
        onTap: () => context.push(Routes.learnerSession(b.id)),
        child: Row(
          children: [
            AppAvatar(name: b.counterpartName ?? '?'),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${b.courseName} with ${(b.counterpartName ?? 'mentor').split(' ').first}',
                    style: AppText.smallSemibold.copyWith(fontSize: 14),
                  ),
                  Text(
                    '${fmtDate(b.startsAt)} · ${fmtTime(b.startsAt)} · $price',
                    style: AppText.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            badge,
          ],
        ),
      ),
    );
  }
}
