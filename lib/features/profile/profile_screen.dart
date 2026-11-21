import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/app_session.dart';
import '../../core/auth/session_controller.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/surfaces.dart';

/// Profile tab for learners and mentors: who you are, (mentor) teaching
/// profile used by matching, switch role, sign out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.pageH,
              Space.xl,
              Space.pageH,
              Space.xxl,
            ),
            children: [
              Text('Profile', style: AppText.h1),
              const SizedBox(height: Space.lg),
              ...profile.when(
                loading: () => [const LoadingView()],
                error: (e, _) => [
                  ErrorView(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(myProfileProvider),
                  ),
                ],
                data: (p) => [
                  _Identity(profile: p, role: role),
                  if (role == UserRole.mentor) ...[
                    const SizedBox(height: Space.xxl),
                    _TeachingEditor(profile: p),
                  ],
                ],
              ),
              const SizedBox(height: Space.xxl),
              _SwitchRole(role: role),
              const SizedBox(height: Space.lg),
              Row(
                children: [
                  const ComingSoonBadge(),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      'Ratings and chat are not part of this prototype.',
                      style: AppText.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.xxl),
              AppButton.secondary(
                label: 'Sign out',
                icon: AppIcons.logout,
                onPressed: () => ref.read(sessionProvider.notifier).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.profile, required this.role});

  final MyProfile profile;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              AppAvatar(
                name: p.fullName.isEmpty ? p.email : p.fullName,
                size: 56,
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.fullName.isEmpty ? 'UB student' : p.fullName,
                      style: AppText.h2,
                    ),
                    Text(
                      [
                        if (p.program != null) p.program!,
                        if (p.cohortYear != null) '${p.cohortYear}',
                      ].join(' '),
                      style: AppText.small.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(role.label, tone: BadgeTone.neutral),
            ],
          ),
          const Divider(height: Space.xxl),
          KeyValueRow(icon: AppIcons.mail, label: 'Email', value: p.email),
          KeyValueRow(icon: AppIcons.user, label: 'NIM', value: maskNim(p.nim)),
        ],
      ),
    );
  }
}

/// Mentor bio + teaching tags. These feed the preference-fit ranking.
class _TeachingEditor extends ConsumerStatefulWidget {
  const _TeachingEditor({required this.profile});

  final MyProfile profile;

  @override
  ConsumerState<_TeachingEditor> createState() => _TeachingEditorState();
}

class _TeachingEditorState extends ConsumerState<_TeachingEditor> {
  late final _bio = TextEditingController(text: widget.profile.bio ?? '');
  late final Set<String> _tags = {...widget.profile.teachingTags};
  bool _saving = false;
  bool _dirty = false;

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  void _toggle(String tag) => setState(() {
    _dirty = true;
    if (!_tags.remove(tag)) _tags.add(tag);
  });

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(repositoryProvider)
          .updateTeaching(bio: _bio.text, tags: _tags.toList());
      ref.invalidate(myProfileProvider);
      setState(() => _dirty = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Teaching profile saved.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _chips(Map<String, String> options) => Wrap(
    spacing: Space.sm,
    runSpacing: Space.sm,
    children: [
      for (final e in options.entries)
        AppChip(
          label: e.value,
          selected: _tags.contains(e.key),
          onTap: () => _toggle(e.key),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Teaching profile', style: AppText.h3),
      const SizedBox(height: Space.xs),
      Text(
        'Learners see your bio. Your tags help us match you with learners '
        'who want the same style.',
        style: AppText.small.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: Space.lg),
      TextField(
        controller: _bio,
        minLines: 3,
        maxLines: 5,
        maxLength: 600,
        onChanged: (_) => setState(() => _dirty = true),
        style: AppText.body,
        decoration: const InputDecoration(
          hintText:
              'e.g. Second-year Informatika student. I explain with small '
              'steps and check each one together.',
        ),
      ),
      const SizedBox(height: Space.md),
      const SectionLabel('How you teach'),
      _chips(kTeachingStyles),
      const SizedBox(height: Space.lg),
      const SectionLabel('Topics and strengths'),
      _chips(kTeachingTopics),
      const SizedBox(height: Space.lg),
      AppButton(
        label: 'Save teaching profile',
        loading: _saving,
        onPressed: _dirty ? _save : null,
      ),
    ],
  );
}

class _SwitchRole extends ConsumerStatefulWidget {
  const _SwitchRole({required this.role});

  final UserRole role;

  @override
  ConsumerState<_SwitchRole> createState() => _SwitchRoleState();
}

class _SwitchRoleState extends ConsumerState<_SwitchRole> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final toMentor = widget.role == UserRole.learner;
    return AppCard(
      child: Row(
        children: [
          Icon(
            toMentor ? AppIcons.mentor : AppIcons.book,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  toMentor ? 'Aced a course?' : 'Need help yourself?',
                  style: AppText.bodyMedium,
                ),
                Text(
                  toMentor
                      ? 'Switch to mentor mode to earn in your class gaps.'
                      : 'Switch to learner mode to find a mentor.',
                  style: AppText.small.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          AppButton.secondary(
            label: toMentor ? 'Switch to mentor' : 'Switch to learner',
            size: AppButtonSize.small,
            expand: false,
            loading: _busy,
            onPressed: () async {
              setState(() => _busy = true);
              try {
                await ref
                    .read(sessionProvider.notifier)
                    .chooseRole(toMentor ? UserRole.mentor : UserRole.learner);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
          ),
        ],
      ),
    );
  }
}
