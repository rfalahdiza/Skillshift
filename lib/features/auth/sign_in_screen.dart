import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/app_session.dart';
import '../../core/auth/session_controller.dart';
import '../../core/config/env.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/surfaces.dart';

/// L03 Sign in with your UB email.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String? _validate(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Enter your UB email.';
    if (!isUbEmail(value)) {
      return 'Use your @student.ub.ac.id or @ub.ac.id address.';
    }
    return null;
  }

  Future<void> _send() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _sending = true);
    final email = _email.text.trim().toLowerCase();
    try {
      await ref.read(sessionProvider.notifier).sendCode(email);
      if (mounted) {
        context.push('${Routes.verify}?email=${Uri.encodeComponent(email)}');
      }
    } on SignInException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
    body: [
      const SizedBox(height: Space.md),
      const Align(alignment: Alignment.centerLeft, child: LogoMark(height: 48)),
      const SizedBox(height: Space.xxl),
      Text('Sign in with your UB email', style: AppText.h1),
      const SizedBox(height: Space.sm),
      Text(
        'Only UB student accounts can join, so every learner and mentor on '
        'SkillShift is a real Brawijaya student.',
        style: AppText.body.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: Space.xxl),
      Form(
        key: _form,
        child: AutofillGroup(
          child: AppTextField(
            label: 'UB email',
            controller: _email,
            hint: 'name@student.ub.ac.id',
            icon: AppIcons.mail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            autofillHints: const [AutofillHints.email],
            validator: _validate,
          ),
        ),
      ),
      const SizedBox(height: Space.xl),
      if (_error != null) ...[
        InfoBanner(tone: BannerTone.danger, text: _error!),
        const SizedBox(height: Space.md),
      ],
      const InfoBanner(
        tone: BannerTone.neutral,
        icon: AppIcons.lock,
        text:
            'We use your email only to sign you in. It is never shown to '
            'other students.',
      ),
      if (!Env.hasSupabase) ...[
        const SizedBox(height: Space.md),
        const InfoBanner(
          tone: BannerTone.warning,
          text:
              'Supabase is not configured. Copy .env.example to .env and run '
              'with --dart-define-from-file=.env.',
        ),
      ],
      if (kDebugMode) const _DevTools(),
    ],
    bottom: BottomActionBar(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: 'Send sign-in code',
              loading: _sending,
              onPressed: _send,
            ),
            const SizedBox(height: Space.md),
            Text(
              'By continuing you agree to the Terms and Privacy Policy.',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Debug builds only: seeded demo accounts, offline preview, gallery.
class _DevTools extends ConsumerStatefulWidget {
  const _DevTools();

  @override
  ConsumerState<_DevTools> createState() => _DevToolsState();
}

class _DevToolsState extends ConsumerState<_DevTools> {
  String? _busy;
  String? _error;

  static const _demoAccounts = [
    ('Nadia Putri · learner', 'nadia.putri@seed.skillshift.test'),
    ('Raka Pratama · mentor', 'raka.pratama@seed.skillshift.test'),
    ('Admin SkillShift · admin', 'admin@seed.skillshift.test'),
  ];

  Future<void> _demo(String email) async {
    setState(() {
      _busy = email;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .demoSignIn(email, Env.demoPassword);
    } on SignInException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.read(sessionProvider.notifier);
    final canDemo = Env.hasSupabase && Env.demoPassword.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: Space.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Dev tools · debug builds only'),
          if (canDemo) ...[
            Text(
              'Demo sign-in with seeded TEST accounts (fake data).',
              style: AppText.small.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: Space.sm),
            for (final (label, email) in _demoAccounts) ...[
              AppButton.secondary(
                label: label,
                loading: _busy == email,
                onPressed: _busy == null ? () => _demo(email) : null,
              ),
              const SizedBox(height: Space.sm),
            ],
            if (_error != null) ...[
              InfoBanner(tone: BannerTone.danger, text: _error!),
              const SizedBox(height: Space.sm),
            ],
            const SizedBox(height: Space.md),
          ],
          Text(
            'Offline preview with sample data (not signed in):',
            style: AppText.small.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final role in UserRole.values)
                AppButton.secondary(
                  label: 'Preview ${role.name}',
                  size: AppButtonSize.small,
                  expand: false,
                  onPressed: () => session.startPreview(role),
                ),
              AppButton.text(
                label: 'Component gallery',
                size: AppButtonSize.small,
                expand: false,
                onPressed: () => context.push(Routes.devComponents),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
