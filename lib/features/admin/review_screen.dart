import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/surfaces.dart';
import 'admin_dashboard_screen.dart';
import 'admin_widgets.dart';

/// Signed link to the KHS for one application (null when there is no file).
final _khsUrlProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, path) => ref.watch(repositoryProvider).khsUrl(path),
  retry: (_, _) => null,
);

/// AD03 Review application (phone) / A03 (wide: KHS left, panel right).
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.applicationId});

  final String applicationId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  bool _nameOk = false;
  bool _gradeOk = false;
  bool _clearOk = false;
  bool _busy = false;

  Future<void> _decide(
    AdminApplication a,
    bool approve, [
    String? reason,
  ]) async {
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(repositoryProvider)
          .reviewApplication(
            a.application.id,
            approve: approve,
            reason: reason,
          );
      refreshAdmin(ref);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? '${a.mentorName} is now a verified mentor for '
                      '${a.application.courseName}.'
                : 'Application rejected. ${a.mentorName.split(' ').first} '
                      'will see your reason.',
          ),
        ),
      );
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(Routes.adminApplications);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(AdminApplication a) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RejectSheet(firstName: a.mentorName.split(' ').first),
    );
    if (reason != null) await _decide(a, false, reason);
  }

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(applicationsProvider);
    final minGpa = ref.watch(appConfigProvider).value?.minGpa ?? 3.5;
    final a = apps.value
        ?.where((x) => x.application.id == widget.applicationId)
        .firstOrNull;
    if (a == null) {
      return PageScaffold(
        header: const PageHeader(title: 'Review application'),
        body: [
          if (apps.isLoading)
            const LoadingView()
          else
            const EmptyView(
              icon: AppIcons.file,
              title: 'Application not found',
            ),
        ],
      );
    }

    final pending = a.application.status == ApplicationStatus.pending;
    final allChecked = _nameOk && _gradeOk && _clearOk;
    final viewer = _KhsViewer(app: a);
    final details = _Details(
      app: a,
      minGpa: minGpa,
      nameOk: _nameOk,
      gradeOk: _gradeOk,
      clearOk: _clearOk,
      onName: (v) => setState(() => _nameOk = v),
      onGrade: (v) => setState(() => _gradeOk = v),
      onClear: (v) => setState(() => _clearOk = v),
    );
    final actions = pending
        ? [
            AppButton(
              label: 'Reject',
              variant: AppButtonVariant.dangerSoft,
              onPressed: _busy ? null : () => _reject(a),
            ),
            AppButton(
              label: 'Approve',
              loading: _busy,
              onPressed: allChecked && !_busy ? () => _decide(a, true) : null,
            ),
          ]
        : <Widget>[];

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 860) {
          return PageScaffold(
            header: const PageHeader(title: 'Review application'),
            body: [
              _Who(app: a, minGpa: minGpa),
              const SizedBox(height: Space.lg),
              viewer,
              const SizedBox(height: Space.lg),
              details,
            ],
            bottom: actions.isEmpty
                ? null
                : BottomActionBar(
                    top: allChecked
                        ? null
                        : Text(
                            'Tick the three checks to approve.',
                            style: AppText.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                    children: actions,
                  ),
          );
        }
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Space.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppBackButton(),
                      const SizedBox(width: Space.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Review application', style: AppText.h2),
                            Text(
                              'Mentor applications / ${a.mentorName}',
                              style: AppText.small.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      applicationBadge(a, minGpa: minGpa),
                    ],
                  ),
                  const SizedBox(height: Space.xl),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: SingleChildScrollView(child: viewer)),
                        const SizedBox(width: Space.xl),
                        SizedBox(
                          width: 380,
                          child: AppCard(
                            padding: const EdgeInsets.all(Space.xl),
                            child: Column(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        _Who(app: a, minGpa: minGpa),
                                        const Divider(height: Space.xxl),
                                        details,
                                      ],
                                    ),
                                  ),
                                ),
                                if (actions.isNotEmpty) ...[
                                  const SizedBox(height: Space.lg),
                                  Row(
                                    children: [
                                      Expanded(child: actions[0]),
                                      const SizedBox(width: Space.md),
                                      Expanded(child: actions[1]),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Who extends StatelessWidget {
  const _Who({required this.app, required this.minGpa});

  final AdminApplication app;
  final double minGpa;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      AppAvatar(name: app.mentorName, size: 48),
      const SizedBox(width: Space.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(app.mentorName, style: AppText.h3),
            Text(
              '${app.application.courseName} · '
              '${formatRupiah(app.application.pricePerHour)}/hr',
              style: AppText.small.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      applicationBadge(app, minGpa: minGpa),
    ],
  );
}

/// The private KHS through a short-lived signed link.
class _KhsViewer extends ConsumerWidget {
  const _KhsViewer({required this.app});

  final AdminApplication app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = app.khsPath;
    final url = path == null ? null : ref.watch(_khsUrlProvider(path));
    final isPdf = (path ?? '').toLowerCase().endsWith('.pdf');
    final fileName = (path ?? '').split('/').last;

    Widget content;
    if (url == null || url.isLoading) {
      content = const LoadingView();
    } else if (url.value == null) {
      content = Column(
        children: [
          const StatusBadge.sample(),
          const SizedBox(height: Space.md),
          Text(
            app.isTestData
                ? 'Seeded test application: there is no real KHS file.'
                : 'The KHS file could not be found.',
            textAlign: TextAlign.center,
            style: AppText.small.copyWith(color: AppColors.textSecondary),
          ),
        ],
      );
    } else if (isPdf) {
      content = Column(
        children: [
          const Icon(AppIcons.file, size: 40, color: AppColors.danger),
          const SizedBox(height: Space.md),
          Text(fileName, style: AppText.smallSemibold),
          const SizedBox(height: Space.lg),
          AppButton(
            label: 'Open KHS (PDF)',
            icon: AppIcons.eye,
            expand: false,
            onPressed: () =>
                launchUrl(Uri.parse(url.value!), webOnlyWindowName: '_blank'),
          ),
        ],
      );
    } else {
      content = ClipRRect(
        borderRadius: Radii.rMd,
        child: InteractiveViewer(
          maxScale: 4,
          child: Image.network(
            url.value!,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Text('Could not load the image.'),
          ),
        ),
      );
    }

    return AppCard(
      color: AppColors.subtle,
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                AppIcons.file,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  fileName.isEmpty ? 'KHS' : fileName,
                  style: AppText.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                AppIcons.lock,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Private · link expires in 5 min',
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Space.xl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: Radii.rMd,
            ),
            child: content,
          ),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.app,
    required this.minGpa,
    required this.nameOk,
    required this.gradeOk,
    required this.clearOk,
    required this.onName,
    required this.onGrade,
    required this.onClear,
  });

  final AdminApplication app;
  final double minGpa;
  final bool nameOk;
  final bool gradeOk;
  final bool clearOk;
  final ValueChanged<bool> onName;
  final ValueChanged<bool> onGrade;
  final ValueChanged<bool> onClear;

  @override
  Widget build(BuildContext context) {
    final a = app.application;
    final pending = a.status == ApplicationStatus.pending;
    final gpaLow = a.proofType == 'gpa' && (a.gpa ?? 0) < minGpa;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Application'),
        KeyValueRow(icon: AppIcons.book, label: 'Course', value: a.courseName),
        KeyValueRow(
          icon: AppIcons.mentor,
          label: 'Program',
          value: '${app.program ?? '—'} ${app.cohortYear ?? ''}',
        ),
        KeyValueRow(icon: AppIcons.user, label: 'NIM', value: maskNim(app.nim)),
        KeyValueRow(
          icon: AppIcons.mail,
          label: 'Email',
          value: app.mentorEmail,
        ),
        KeyValueRow(
          icon: AppIcons.wallet,
          label: 'Price',
          value: '${formatRupiah(a.pricePerHour)}/hr',
        ),
        KeyValueRow(
          icon: AppIcons.verified,
          label: 'Proof',
          value: app.proofLabel,
        ),
        const SizedBox(height: Space.lg),
        const SectionLabel('Checked by the system'),
        const _AutoCheck('Price within the suggested range'),
        const _AutoCheck('Signed: no graded work for learners'),
        const SizedBox(height: Space.lg),
        SectionLabel(pending ? 'Confirm by eye on the KHS' : 'Result'),
        if (pending) ...[
          CheckRow(
            value: nameOk,
            onChanged: onName,
            label: 'Name on the KHS matches ${app.mentorName}',
          ),
          CheckRow(
            value: gradeOk,
            onChanged: onGrade,
            label: a.proofType == 'gpa'
                ? 'GPA on the KHS is ${a.gpa?.toStringAsFixed(2) ?? '—'}'
                : 'Grade for ${a.courseName} is A',
          ),
          CheckRow(
            value: clearOk,
            onChanged: onClear,
            label: 'Document is clear and complete',
          ),
          if (gpaLow) ...[
            const SizedBox(height: Space.sm),
            InfoBanner(
              tone: BannerTone.info,
              icon: AppIcons.info,
              text:
                  'GPA ${a.gpa?.toStringAsFixed(2)} is below the '
                  '${minGpa.toStringAsFixed(2)} requirement. Approve only if '
                  'the KHS also shows an A in ${a.courseName}.',
            ),
          ],
        ] else if (a.status == ApplicationStatus.rejected)
          InfoBanner(
            tone: BannerTone.danger,
            icon: AppIcons.info,
            text: 'Rejected: ${a.rejectReason ?? ''}',
          )
        else
          const InfoBanner(text: 'Approved. This mentor appears in matches.'),
      ],
    );
  }
}

class _AutoCheck extends StatelessWidget {
  const _AutoCheck(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        const Icon(AppIcons.checkCircle, size: 18, color: AppColors.primary),
        const SizedBox(width: Space.md),
        Expanded(child: Text(text, style: AppText.small)),
      ],
    ),
  );
}

/// AD04 Reject application? Reason chips + note (required).
class _RejectSheet extends StatefulWidget {
  const _RejectSheet({required this.firstName});

  final String firstName;

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  static const _reasons = {
    'Grade not readable':
        'The grade column is blurry. Please upload a clearer scan or the PDF '
        'from SIAM.',
    'Wrong course': 'The KHS does not show this course.',
    'Below requirement':
        'The KHS shows neither an A in this course nor a GPA of 3.50 or '
        'higher.',
    'Name mismatch': 'The name on the KHS does not match your UB account.',
  };

  String? _chip;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
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
          Text('Reject application?', style: AppText.h2),
          const SizedBox(height: Space.xs),
          Text(
            '${widget.firstName} will see your reason and can apply again.',
            style: AppText.small.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: Space.lg),
          const SectionLabel('Reason'),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final r in _reasons.keys)
                AppChip(
                  label: r,
                  selected: _chip == r,
                  onTap: () => setState(() {
                    _chip = r;
                    _note.text = _reasons[r]!;
                  }),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            style: AppText.body,
            decoration: const InputDecoration(
              hintText: 'Tell the applicant what to fix.',
              counterText: '',
            ),
          ),
          const SizedBox(height: Space.lg),
          AppButton(
            label: 'Reject application',
            variant: AppButtonVariant.danger,
            onPressed: _note.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, _note.text.trim()),
          ),
          AppButton.text(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}
