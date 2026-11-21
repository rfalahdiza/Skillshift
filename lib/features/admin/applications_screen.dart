import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/surfaces.dart';
import 'admin_dashboard_screen.dart';
import 'admin_widgets.dart';

/// AD02 Applications (phone) / A02 Mentor applications (wide table).
class ApplicationsScreen extends ConsumerStatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  ConsumerState<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends ConsumerState<ApplicationsScreen> {
  ApplicationStatus _tab = ApplicationStatus.pending;
  String _query = '';

  bool _matches(AdminApplication a) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return a.mentorName.toLowerCase().contains(q) ||
        (a.nim ?? '').contains(q) ||
        a.application.courseName.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(applicationsProvider);
    final minGpa = ref.watch(appConfigProvider).value?.minGpa ?? 3.5;
    final all = apps.value ?? const <AdminApplication>[];
    int count(ApplicationStatus s) =>
        all.where((a) => a.application.status == s).length;
    final shown =
        all.where((a) => a.application.status == _tab && _matches(a)).toList()
          ..sort(
            (a, b) => _tab == ApplicationStatus.pending
                ? a.application.createdAt.compareTo(b.application.createdAt)
                : b.application.createdAt.compareTo(a.application.createdAt),
          );

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          refreshAdmin(ref);
          await ref.read(applicationsProvider.future);
        },
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 860;
            final tabs = _Tabs(
              expand: !wide,
              current: _tab,
              counts: {for (final s in ApplicationStatus.values) s: count(s)},
              onChanged: (s) => setState(() => _tab = s),
            );
            final search = TextField(
              onChanged: (v) => setState(() => _query = v),
              style: AppText.body,
              decoration: const InputDecoration(
                hintText: 'Search name, NIM or course',
                prefixIcon: Icon(
                  AppIcons.search,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ),
            );

            final Widget body;
            if (apps.isLoading && apps.value == null) {
              body = const LoadingView();
            } else if (apps.hasError) {
              body = ErrorView(
                message: apps.error.toString(),
                onRetry: () => ref.invalidate(applicationsProvider),
              );
            } else if (shown.isEmpty) {
              body = EmptyView(
                icon: AppIcons.file,
                title: _query.isEmpty
                    ? 'No ${_tab.name} applications'
                    : 'No match for "$_query"',
              );
            } else if (wide) {
              body = ApplicationsTable(apps: shown, minGpa: minGpa);
            } else {
              body = AppCard(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: Column(
                  children: [
                    for (final (i, a) in shown.indexed) ...[
                      if (i > 0) const Divider(),
                      ApplicationTile(
                        app: a,
                        minGpa: minGpa,
                        onTap: () =>
                            context.push(Routes.adminReview(a.application.id)),
                      ),
                    ],
                  ],
                ),
              );
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(
                wide ? Space.xxl : Space.pageH,
                Space.xl,
                wide ? Space.xxl : Space.pageH,
                Space.xxl,
              ),
              children: [
                Text(
                  wide ? 'Mentor applications' : 'Applications',
                  style: AppText.h1,
                ),
                if (wide)
                  Text(
                    'Verify the KHS before a mentor appears in matches.',
                    style: AppText.small.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: Space.lg),
                if (wide)
                  Row(
                    children: [
                      tabs,
                      const Spacer(),
                      SizedBox(width: 320, child: search),
                    ],
                  )
                else ...[
                  tabs,
                  const SizedBox(height: Space.md),
                  search,
                ],
                const SizedBox(height: Space.lg),
                body,
                if (wide && shown.isNotEmpty) ...[
                  const SizedBox(height: Space.md),
                  Text(
                    'Showing ${shown.length} of ${all.length} applications',
                    style: AppText.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.current,
    required this.counts,
    required this.onChanged,
    this.expand = false,
  });

  /// Phone: tabs share the full width.
  final bool expand;

  final ApplicationStatus current;
  final Map<ApplicationStatus, int> counts;
  final ValueChanged<ApplicationStatus> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: AppColors.subtle, borderRadius: Radii.rMd),
    child: Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (final s in ApplicationStatus.values)
          _wrap(
            Semantics(
              selected: s == current,
              button: true,
              child: Material(
                color: s == current ? AppColors.surface : Colors.transparent,
                borderRadius: Radii.rSm,
                child: InkWell(
                  borderRadius: Radii.rSm,
                  onTap: () => onChanged(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.md,
                      vertical: 8,
                    ),
                    child: Text(
                      '${s.name[0].toUpperCase()}${s.name.substring(1)}'
                      ' · ${counts[s] ?? 0}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.smallSemibold.copyWith(
                        color: s == current
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _wrap(Widget child) => expand ? Expanded(child: child) : child;
}
