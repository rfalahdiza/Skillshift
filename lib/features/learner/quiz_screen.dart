import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/surfaces.dart';

/// L07 A few quick questions. [setup] = onboarding step 2 of 2.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, this.setup = false});

  final bool setup;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  String? _courseId;
  LearningStyle _style = LearningStyle.workedExamples;
  final _answer = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _courseId = ref.read(selectedCourseProvider);
    if (_courseId != null) _prefill(_courseId!);
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _prefill(String courseId) async {
    final pref = await ref.read(preferenceProvider(courseId).future);
    if (!mounted || pref == null || _courseId != courseId) return;
    setState(() {
      _style = pref.style;
      _answer.text = pref.openAnswer ?? '';
    });
  }

  void _selectCourse(String id) {
    setState(() => _courseId = id);
    _prefill(id);
  }

  Future<void> _submit() async {
    final courseId = _courseId;
    if (courseId == null) {
      setState(() => _error = 'Pick the course you need help with.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final router = GoRouter.of(context);
    try {
      final answer = _answer.text.trim();
      await ref
          .read(repositoryProvider)
          .savePreference(
            courseId: courseId,
            style: _style,
            openAnswer: answer.isEmpty ? null : answer,
          );
      ref.invalidate(preferenceProvider(courseId));
      ref.read(selectedCourseProvider.notifier).select(courseId);
      // Fresh matches for the new answers.
      ref.invalidate(matchesProvider);
      router.go(Routes.learnerFind);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(coursesProvider);
    return PageScaffold(
      header: PageHeader(
        title: 'A few quick questions',
        trailing: widget.setup ? 'Step 2 of 2' : null,
        onBack: () => context.canPop()
            ? context.pop()
            : context.go(
                widget.setup
                    ? Routes.learnerSetupTimetable
                    : Routes.learnerHome,
              ),
      ),
      body: [
        if (widget.setup) ...[
          const StepProgress(current: 2, total: 2),
          const SizedBox(height: Space.xl),
        ],
        Text('Which course do you need help with?', style: AppText.h3),
        const SizedBox(height: Space.md),
        courses.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(coursesProvider),
          ),
          data: (list) => Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final c in list)
                AppChip(
                  label: c.name,
                  selected: _courseId == c.id,
                  onTap: () => _selectCourse(c.id),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.xxl),
        Text('How do you like to learn?', style: AppText.h3),
        const SizedBox(height: Space.md),
        for (final s in LearningStyle.values) ...[
          OptionCard(
            title: s.label,
            compact: true,
            selected: _style == s,
            onTap: () => setState(() => _style = s),
          ),
          const SizedBox(height: Space.md),
        ],
        const SizedBox(height: Space.md),
        Text('Anything your mentor should know?', style: AppText.h3),
        const SizedBox(height: Space.md),
        TextField(
          controller: _answer,
          maxLines: 4,
          minLines: 3,
          maxLength: 500,
          style: AppText.body,
          decoration: const InputDecoration(
            hintText:
                'e.g. I get lost when limits turn into derivatives. Someone '
                'patient would help.',
            counterText: '',
          ),
        ),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            const Icon(AppIcons.sparkle, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'We turn this into preference tags with AI. Please don’t '
                'include personal details.',
                style: AppText.caption.copyWith(color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: Space.lg),
          InfoBanner(tone: BannerTone.danger, text: _error!),
        ],
      ],
      bottom: BottomActionBar(
        children: [
          AppButton(
            label: 'Find my mentors',
            loading: _saving,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
