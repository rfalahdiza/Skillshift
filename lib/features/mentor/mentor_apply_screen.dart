import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_controller.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/surfaces.dart';

const _maxKhsBytes = 5 * 1024 * 1024;
const _minGpa = 3.5;

/// M01 → M02.
class ApplyArgs {
  const ApplyArgs({
    required this.course,
    required this.khsPath,
    required this.proofType,
    this.gpa,
  });

  final Course course;
  final String khsPath;
  final String proofType;
  final double? gpa;
}

/// M01 Become a mentor: course, how you qualify, KHS upload (private).
class MentorApplyScreen extends ConsumerStatefulWidget {
  const MentorApplyScreen({super.key});

  @override
  ConsumerState<MentorApplyScreen> createState() => _MentorApplyScreenState();
}

class _MentorApplyScreenState extends ConsumerState<MentorApplyScreen> {
  Course? _course;
  String _proof = 'grade_a';
  final _gpa = TextEditingController();
  String? _khsPath;
  String? _khsName;
  int? _khsSize;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _gpa.dispose();
    super.dispose();
  }

  double? get _gpaValue => double.tryParse(_gpa.text.replaceAll(',', '.'));

  bool get _gpaValid =>
      _proof == 'grade_a' ||
      (_gpaValue != null && _gpaValue! >= 0 && _gpaValue! <= 4);

  Future<void> _pickCourse(List<Course> options) async {
    final picked = await showModalBottomSheet<Course>(
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
              child: Text('Course you want to teach', style: AppText.h2),
            ),
            for (final c in options)
              ListTile(
                title: Text(c.name, style: AppText.bodyMedium),
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _course = picked);
  }

  Future<void> _upload(List<int> bytes, String name) async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final path = await ref.read(repositoryProvider).uploadKhs(bytes, name);
      setState(() {
        _khsPath = path;
        _khsName = name;
        _khsSize = bytes.length;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickFile() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (bytes.length > _maxKhsBytes) {
      setState(() => _error = 'The file is larger than 5 MB.');
      return;
    }
    await _upload(bytes, f.name);
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(coursesProvider);
    final overview = ref.watch(mentorOverviewProvider).value;
    final preview = ref.watch(
      sessionProvider.select((s) => s.value?.isPreview ?? false),
    );
    // Courses already verified or waiting are not offered again.
    final taken = {
      ...?overview?.courses.map((c) => c.courseId),
      ...?overview?.applications
          .where((a) => a.status == ApplicationStatus.pending)
          .map((a) => a.courseId),
    };
    final options = (courses.value ?? const <Course>[])
        .where((c) => !taken.contains(c.id))
        .toList();

    final canNext = _course != null && _khsPath != null && _gpaValid;

    return PageScaffold(
      header: PageHeader(
        title: 'Become a mentor',
        trailing: 'Step 1 of 2',
        onBack: () =>
            context.canPop() ? context.pop() : context.go(Routes.mentorHome),
      ),
      body: [
        const StepProgress(current: 1, total: 2),
        const SizedBox(height: Space.xl),
        Text('Show you aced the course', style: AppText.h1),
        const SizedBox(height: Space.sm),
        Text(
          'Upload your KHS. You qualify with an A in the course or a GPA of '
          '3.5 or higher.',
          style: AppText.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Space.xl),
        if (courses.isLoading)
          const LoadingView()
        else
          SelectField(
            label: 'Course you want to teach',
            value: _course?.name,
            onTap: () => _pickCourse(options),
          ),
        const SizedBox(height: Space.lg),
        Text(
          'How you qualify',
          style: AppText.smallMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          children: [
            AppChip(
              label: 'A in this course',
              selected: _proof == 'grade_a',
              onTap: () => setState(() => _proof = 'grade_a'),
            ),
            AppChip(
              label: 'GPA 3.5 or higher',
              selected: _proof == 'gpa',
              onTap: () => setState(() => _proof = 'gpa'),
            ),
          ],
        ),
        if (_proof == 'gpa') ...[
          const SizedBox(height: Space.md),
          AppTextField(
            label: 'Your GPA (IPK)',
            controller: _gpa,
            hint: 'e.g. 3.71',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          if (_gpaValue != null && _gpaValue! < _minGpa) ...[
            const SizedBox(height: Space.sm),
            const InfoBanner(
              tone: BannerTone.info,
              text:
                  'Below 3.50 can still be sent, but the admin will check it '
                  'by hand and may reject it.',
            ),
          ],
        ],
        const SizedBox(height: Space.lg),
        Text(
          'KHS (study result card)',
          style: AppText.smallMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Space.sm),
        AppCard(
          dashed: true,
          color: AppColors.surface,
          onTap: _uploading ? null : _pickFile,
          padding: const EdgeInsets.symmetric(vertical: Space.xxl),
          child: Center(
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: Radii.rMd,
                  ),
                  child: _uploading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.upload, color: AppColors.primary),
                ),
                const SizedBox(height: Space.md),
                Text('Tap to upload PDF or photo', style: AppText.bodyMedium),
                Text(
                  'Max 5 MB',
                  style: AppText.small.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ),
        if (preview && _khsPath == null)
          AppButton.text(
            label: 'Use a sample KHS (preview)',
            size: AppButtonSize.small,
            onPressed: () => _upload(List.filled(1024, 0), 'KHS_sample.pdf'),
          ),
        if (_khsPath != null) ...[
          const SizedBox(height: Space.md),
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: Radii.rMd,
                  ),
                  child: const Icon(AppIcons.file, color: AppColors.danger),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _khsName!,
                        style: AppText.smallSemibold.copyWith(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${((_khsSize ?? 0) / 1024).ceil()} KB · uploaded',
                        style: AppText.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(AppIcons.checkCircle, color: AppColors.primary),
              ],
            ),
          ),
        ],
        const SizedBox(height: Space.lg),
        const InfoBanner(
          tone: BannerTone.neutral,
          icon: AppIcons.lock,
          text:
              'Stored privately. Only the SkillShift admin can see it, and '
              'only to verify you.',
        ),
        if (_error != null) ...[
          const SizedBox(height: Space.md),
          InfoBanner(tone: BannerTone.danger, text: _error!),
        ],
      ],
      bottom: BottomActionBar(
        children: [
          AppButton(
            label: 'Next',
            onPressed: canNext
                ? () => context.push(
                    Routes.mentorApplyPrice,
                    extra: ApplyArgs(
                      course: _course!,
                      khsPath: _khsPath!,
                      proofType: _proof,
                      gpa: _proof == 'gpa' ? _gpaValue : null,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// M02 Set your price + mentor agreement.
class MentorPriceScreen extends ConsumerStatefulWidget {
  const MentorPriceScreen({super.key, required this.args});

  final ApplyArgs? args;

  @override
  ConsumerState<MentorPriceScreen> createState() => _MentorPriceScreenState();
}

class _MentorPriceScreenState extends ConsumerState<MentorPriceScreen> {
  ({int min, int max})? _range;
  double _price = 25000;
  bool _noGraded = false;
  bool _onCampus = false;
  bool _sending = false;
  String? _error;

  static const _step = 2500;

  @override
  void initState() {
    super.initState();
    final a = widget.args;
    if (a != null) _loadRange(a.course.id);
  }

  Future<void> _loadRange(String courseId) async {
    try {
      final r = await ref.read(repositoryProvider).priceRange(courseId);
      if (!mounted) return;
      setState(() {
        _range = r;
        _price = _price.clamp(r.min.toDouble(), r.max.toDouble());
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _submit() async {
    final a = widget.args!;
    setState(() {
      _sending = true;
      _error = null;
    });
    final router = GoRouter.of(context);
    try {
      await ref
          .read(repositoryProvider)
          .submitApplication(
            ApplicationDraft(
              courseId: a.course.id,
              khsPath: a.khsPath,
              proofType: a.proofType,
              gpa: a.gpa,
              pricePerHour: _price.round(),
            ),
          );
      ref.invalidate(mentorOverviewProvider);
      router.go(Routes.mentorPending);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    if (a == null) {
      return PageScaffold(
        header: const PageHeader(title: 'Set your price'),
        body: [
          EmptyView(
            icon: AppIcons.file,
            title: 'Start with your KHS',
            action: 'Become a mentor',
            onAction: () => context.go(Routes.mentorApply),
          ),
        ],
      );
    }
    final r = _range;
    final divisions = r == null ? null : ((r.max - r.min) ~/ _step);

    return PageScaffold(
      header: const PageHeader(
        title: 'Set your price',
        trailing: 'Step 2 of 2',
      ),
      body: [
        const StepProgress(current: 2, total: 2),
        const SizedBox(height: Space.xl),
        Text('How much per hour?', style: AppText.h1),
        const SizedBox(height: Space.sm),
        Text(
          'Pick a price inside the suggested range for ${a.course.name}.',
          style: AppText.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Space.xl),
        AppCard(
          padding: const EdgeInsets.all(Space.xl),
          child: r == null
              ? const LoadingView()
              : Column(
                  children: [
                    Text(formatRupiah(_price.round()), style: AppText.amount),
                    Text(
                      'per hour',
                      style: AppText.small.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    Slider(
                      value: _price,
                      min: r.min.toDouble(),
                      max: r.max.toDouble(),
                      divisions: divisions == null || divisions < 1
                          ? null
                          : divisions,
                      label: formatRupiah(_price.round()),
                      onChanged: (v) => setState(() => _price = v),
                    ),
                    Row(
                      children: [
                        Text(
                          formatRupiah(r.min),
                          style: AppText.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Suggested range',
                            textAlign: TextAlign.center,
                            style: AppText.caption.copyWith(
                              color: AppColors.primaryPressed,
                            ),
                          ),
                        ),
                        Text(
                          formatRupiah(r.max),
                          style: AppText.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        const SizedBox(height: Space.lg),
        const InfoBanner(
          icon: AppIcons.gift,
          text:
              'Your first 30-minute session with each new learner is free. It '
              'helps learners try you out.',
        ),
        const SizedBox(height: Space.xl),
        const SectionLabel('Mentor agreement'),
        AppCard(
          child: Column(
            children: [
              CheckRow(
                value: _noGraded,
                onChanged: (v) => setState(() => _noGraded = v),
                label:
                    'I won’t do graded assignments, quizzes, or exams for '
                    'learners.',
              ),
              const SizedBox(height: Space.md),
              CheckRow(
                value: _onCampus,
                onChanged: (v) => setState(() => _onCampus = v),
                label:
                    'I’ll meet on campus at the booked time and confirm '
                    'attendance.',
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: Space.md),
          InfoBanner(tone: BannerTone.danger, text: _error!),
        ],
      ],
      bottom: BottomActionBar(
        children: [
          AppButton(
            label: 'Submit for verification',
            loading: _sending,
            onPressed: r != null && _noGraded && _onCampus ? _submit : null,
          ),
        ],
      ),
    );
  }
}
