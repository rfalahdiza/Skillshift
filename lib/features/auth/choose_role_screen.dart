import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/app_session.dart';
import '../../core/auth/session_controller.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/surfaces.dart';

/// L05 How do you want to use SkillShift?
class ChooseRoleScreen extends ConsumerStatefulWidget {
  const ChooseRoleScreen({super.key});

  @override
  ConsumerState<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

class _ChooseRoleScreenState extends ConsumerState<ChooseRoleScreen> {
  UserRole _role = UserRole.learner;
  bool _saving = false;
  String? _error;

  Future<void> _continue() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    // Saving the role triggers the router redirect, which may dispose this
    // screen, so keep the router before awaiting.
    final router = GoRouter.of(context);
    final role = _role;
    try {
      await ref.read(sessionProvider.notifier).chooseRole(role);
      // New learners set up their timetable first (L06 → L07).
      if (role == UserRole.learner) router.go(Routes.learnerSetupTimetable);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save your choice. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
    body: [
      const SizedBox(height: Space.xxl),
      Text('How do you want to use SkillShift?', style: AppText.h1),
      const SizedBox(height: Space.sm),
      Text(
        'You can switch anytime from your profile.',
        style: AppText.body.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: Space.xxl),
      OptionCard(
        title: 'I want to learn',
        subtitle:
            'Get course help from a verified senior. Your first session with '
            'each mentor is free.',
        icon: AppIcons.book,
        selected: _role == UserRole.learner,
        onTap: () => setState(() => _role = UserRole.learner),
      ),
      const SizedBox(height: Space.md),
      OptionCard(
        title: 'I want to mentor',
        subtitle:
            'Earn in your class gaps by helping juniors in a course you aced.',
        icon: AppIcons.mentor,
        selected: _role == UserRole.mentor,
        onTap: () => setState(() => _role = UserRole.mentor),
      ),
      if (_error != null) ...[
        const SizedBox(height: Space.lg),
        InfoBanner(tone: BannerTone.danger, text: _error!),
      ],
    ],
    bottom: BottomActionBar(
      children: [
        AppButton(label: 'Continue', loading: _saving, onPressed: _continue),
      ],
    ),
  );
}
