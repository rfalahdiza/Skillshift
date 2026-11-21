import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/gaps.dart';
import '../../core/utils/time.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/surfaces.dart';

/// L06 Your timetable. [setup] = onboarding step 1 of 2; otherwise the
/// learner's Timetable tab.
class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key, this.setup = false});

  final bool setup;

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  late int _day = _initialDay();

  static int _initialDay() {
    final d = Wib.now().weekday;
    return d > 5 ? 1 : d;
  }

  Future<void> _add() async {
    final draft = await showModalBottomSheet<TimetableDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddClassSheet(initialDay: _day),
    );
    if (draft == null) return;
    try {
      await ref.read(timetableProvider.notifier).add(draft);
      setState(() => _day = draft.dayOfWeek);
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _remove(TimetableEntry e) async {
    final ok = await showModalBottomSheet<bool>(
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
            Text(e.courseName, style: AppText.h2),
            Text(
              '${weekdayLong[e.dayOfWeek - 1]} ${hm(e.start)} to ${hm(e.end)}',
              style: AppText.small.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: Space.xl),
            AppButton(
              label: 'Remove class',
              variant: AppButtonVariant.dangerSoft,
              onPressed: () => Navigator.pop(ctx, true),
            ),
            AppButton.text(
              label: 'Cancel',
              onPressed: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(timetableProvider.notifier).remove(e.id);
    } catch (err) {
      _snack(err.toString());
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final timetable = ref.watch(timetableProvider);
    final entries = timetable.value ?? const <TimetableEntry>[];
    final hasClasses = entries.isNotEmpty;

    final body = <Widget>[
      if (widget.setup) ...[
        const StepProgress(current: 1, total: 2),
        const SizedBox(height: Space.lg),
      ],
      Text(
        'Add your classes so we can find mentors who are free in your gaps.',
        style: AppText.body.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: Space.lg),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var d = 1; d <= 5; d++) ...[
              AppChip(
                label: weekdayShort[d - 1],
                selected: _day == d,
                onTap: () => setState(() => _day = d),
              ),
              const SizedBox(width: Space.sm),
            ],
          ],
        ),
      ),
      const SizedBox(height: Space.lg),
      timetable.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(timetableProvider),
        ),
        data: (_) => DayAgenda(
          entries: entries.where((e) => e.dayOfWeek == _day).toList(),
          onTapEntry: _remove,
        ),
      ),
    ];

    return PageScaffold(
      header: PageHeader(
        title: widget.setup ? 'Your timetable' : 'Timetable',
        trailing: widget.setup ? 'Step 1 of 2' : null,
        showBack: widget.setup,
        onBack: () => context.go(Routes.chooseRole),
      ),
      body: body,
      bottom: BottomActionBar(
        children: widget.setup
            ? [
                AppButton.secondary(label: 'Add class', onPressed: _add),
                AppButton(
                  label: 'Next',
                  onPressed: hasClasses
                      ? () => context.go(Routes.learnerSetupQuiz)
                      : null,
                ),
              ]
            : [
                AppButton.secondary(
                  label: 'Add class',
                  icon: AppIcons.plus,
                  onPressed: _add,
                ),
              ],
      ),
    );
  }
}

/// One day's classes with the free gaps between them.
class DayAgenda extends StatelessWidget {
  const DayAgenda({super.key, required this.entries, this.onTapEntry});

  final List<TimetableEntry> entries;
  final ValueChanged<TimetableEntry>? onTapEntry;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const EmptyView(
        icon: AppIcons.calendar,
        title: 'No classes on this day',
        message: 'Tap "Add class" to add one. Empty days are free all day.',
      );
    }
    final sorted = [...entries]..sort((a, b) => a.start.compareTo(b.start));
    final gaps = gapsBetweenClasses(sorted.map((e) => e.range));
    final rows = <(int, Widget)>[
      for (final e in sorted) (e.start, _ClassRow(entry: e, onTap: onTapEntry)),
      for (final g in gaps) (g.start, _GapRow(gap: g)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: r.$2,
          ),
      ],
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.entry, this.onTap});

  final TimetableEntry entry;
  final ValueChanged<TimetableEntry>? onTap;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 64,
        child: Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hm(entry.start), style: AppText.smallSemibold),
              Text(
                hm(entry.end),
                style: AppText.small.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
      Expanded(
        child: AppCard(
          onTap: onTap == null ? null : () => onTap!(entry),
          padding: const EdgeInsets.all(Space.lg),
          radius: Radii.md,
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: Radii.rFull,
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.courseName, style: AppText.bodyMedium),
                      if (entry.room != null && entry.room!.isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              AppIcons.pin,
                              size: 14,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                entry.room!,
                                style: AppText.small.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _GapRow extends StatelessWidget {
  const _GapRow({required this.gap});

  final TimeRange gap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 64,
        child: Text(
          hm(gap.start),
          style: AppText.small.copyWith(color: AppColors.textTertiary),
        ),
      ),
      Expanded(
        child: AppCard(
          dashed: true,
          radius: Radii.md,
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.md,
          ),
          child: Row(
            children: [
              const Icon(
                AppIcons.clock,
                size: 18,
                color: AppColors.primaryPressed,
              ),
              const SizedBox(width: Space.sm),
              Text(
                'Free gap · ${gap.minutes} min',
                style: AppText.smallMedium.copyWith(
                  color: AppColors.primaryPressed,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Bottom sheet to add a class.
class AddClassSheet extends ConsumerStatefulWidget {
  const AddClassSheet({super.key, required this.initialDay});

  final int initialDay;

  @override
  ConsumerState<AddClassSheet> createState() => _AddClassSheetState();
}

class _AddClassSheetState extends ConsumerState<AddClassSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _room = TextEditingController();
  late int _day = widget.initialDay;
  int _start = 7 * 60;
  int _end = 9 * 60 + 30;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final current = start ? _start : _end;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null) return;
    setState(() {
      final m = t.hour * 60 + t.minute;
      if (start) {
        _start = m;
        if (_end <= _start) _end = (_start + 100).clamp(0, 24 * 60 - 1);
      } else {
        _end = m;
      }
    });
  }

  void _save() {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    if (_end <= _start) {
      setState(() => _error = 'The class must end after it starts.');
      return;
    }
    Navigator.pop(
      context,
      TimetableDraft(
        dayOfWeek: _day,
        start: _start,
        end: _end,
        courseName: _name.text.trim(),
        room: _room.text.trim().isEmpty ? null : _room.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(coursesProvider).value ?? const <Course>[];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Space.pageH,
          0,
          Space.pageH,
          Space.xxl,
        ),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add class', style: AppText.h2),
              const SizedBox(height: Space.lg),
              AppTextField(
                label: 'Class',
                controller: _name,
                hint: 'e.g. Kalkulus 1',
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter the class name.' : null,
              ),
              if (courses.isNotEmpty) ...[
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (final c in courses)
                      AppChip(
                        label: c.name,
                        style: ChipStyle.soft,
                        selected: _name.text == c.name,
                        onTap: () => setState(() => _name.text = c.name),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: Space.lg),
              const SectionLabel('Day'),
              Wrap(
                spacing: Space.sm,
                children: [
                  for (var d = 1; d <= 5; d++)
                    AppChip(
                      label: weekdayShort[d - 1],
                      selected: _day == d,
                      onTap: () => setState(() => _day = d),
                    ),
                ],
              ),
              const SizedBox(height: Space.lg),
              Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      label: 'Starts',
                      value: hm(_start),
                      onTap: () => _pick(true),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: _TimeField(
                      label: 'Ends',
                      value: hm(_end),
                      onTap: () => _pick(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.lg),
              AppTextField(
                label: 'Room (optional)',
                controller: _room,
                hint: 'e.g. Gedung F 2.3',
                icon: AppIcons.pin,
              ),
              if (_error != null) ...[
                const SizedBox(height: Space.md),
                InfoBanner(tone: BannerTone.danger, text: _error!),
              ],
              const SizedBox(height: Space.xl),
              AppButton(label: 'Save class', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SelectField(
    label: label,
    value: value,
    icon: AppIcons.clock,
    onTap: onTap,
  );
}
