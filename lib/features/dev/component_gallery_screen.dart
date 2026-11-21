import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/mentor_match_card.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/surfaces.dart';

/// Debug-only catalogue of the shared widgets, for checking against the
/// Figma `00 Design System` page. All content here is sample data.
class ComponentGalleryScreen extends StatefulWidget {
  const ComponentGalleryScreen({super.key});

  @override
  State<ComponentGalleryScreen> createState() => _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState extends State<ComponentGalleryScreen> {
  int _role = 0;
  int _slot = 0;
  String _chip = 'Kalkulus 1';
  bool _agree = true;

  static const _sample = MentorMatchData(
    mentorId: 'sample',
    name: 'Raka Pratama',
    program: 'Informatika',
    cohortYear: 2024,
    proof: 'A in Kalkulus 1',
    reason:
        'Free in your Tue 12:00 gap and teaches with worked examples, '
        'which you asked for.',
    slotLabel: 'Tue 12:00 to 13:00',
    pricePerHour: 25000,
  );

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(top: Space.xxl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [SectionLabel(title), ...children],
    ),
  );

  Widget _gap([double h = Space.md]) => SizedBox(height: h);

  @override
  Widget build(BuildContext context) => PageScaffold(
    header: const PageHeader(title: 'Component gallery', trailing: 'Debug'),
    body: [
      const InfoBanner(
        tone: BannerTone.warning,
        text: 'Debug-only screen. Everything below is sample data.',
      ),
      _section('Brand', const [
        Row(
          children: [
            LogoMark(height: 56),
            SizedBox(width: Space.xl),
            Wordmark(),
          ],
        ),
        SizedBox(height: Space.md),
        BrandLockup(),
      ]),
      _section('Typography', [
        Text('Display 28/34', style: AppText.display),
        Text('H1 24/30', style: AppText.h1),
        Text('H2 18/24', style: AppText.h2),
        Text('H3 16/22', style: AppText.h3),
        Text('Body 15/22', style: AppText.body),
        Text('Body medium 15/22', style: AppText.bodyMedium),
        Text('Small 13/18', style: AppText.small),
        Text('Caption 12/16', style: AppText.caption),
        Text('OVERLINE 11/14', style: AppText.overline),
        Text('Rp25.000', style: AppText.amount),
      ]),
      _section('Buttons', [
        AppButton(label: 'Get started', onPressed: () {}),
        _gap(),
        AppButton.secondary(label: 'Add class', onPressed: () {}),
        _gap(),
        const AppButton(
          label: 'Waiting for Raka',
          variant: AppButtonVariant.soft,
          onPressed: null,
        ),
        _gap(),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Reject',
                variant: AppButtonVariant.dangerSoft,
                onPressed: () {},
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: AppButton(label: 'Approve', onPressed: () {}),
            ),
          ],
        ),
        _gap(),
        AppButton(
          label: 'Reject application',
          variant: AppButtonVariant.danger,
          onPressed: () {},
        ),
        AppButton.text(label: 'Back to home', onPressed: () {}),
        _gap(),
        Row(
          children: [
            AppButton.secondary(
              label: 'Decline',
              size: AppButtonSize.small,
              expand: false,
              onPressed: () {},
            ),
            const SizedBox(width: Space.sm),
            AppButton(
              label: 'Accept',
              size: AppButtonSize.small,
              expand: false,
              onPressed: () {},
            ),
            const SizedBox(width: Space.sm),
            const AppButton(
              label: 'Loading',
              size: AppButtonSize.small,
              expand: false,
              loading: true,
              onPressed: null,
            ),
          ],
        ),
        _gap(),
        Row(
          children: [
            const AppBackButton(),
            const SizedBox(width: Space.md),
            AppIconButton(
              icon: AppIcons.bell,
              tooltip: 'Notifications',
              onPressed: () {},
            ),
          ],
        ),
      ]),
      _section('Chips and slots', [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final c in const [
              'Kalkulus 1',
              'Pemrograman Dasar',
              'Matematika Komputasi',
              'Fisika Dasar',
            ])
              AppChip(
                label: c,
                selected: _chip == c,
                onTap: () => setState(() => _chip = c),
              ),
            const AppChip(
              label: 'Kalkulus 1',
              selected: true,
              style: ChipStyle.soft,
            ),
            const AppChip(label: 'Disabled', enabled: false),
          ],
        ),
        _gap(),
        Row(
          children: [
            for (final (i, t) in const ['12:00', '12:30', '13:00'].indexed) ...[
              if (i > 0) const SizedBox(width: Space.sm),
              Expanded(
                child: SlotTile(
                  label: t,
                  selected: _slot == i,
                  enabled: i != 2,
                  onTap: () => setState(() => _slot = i),
                ),
              ),
            ],
          ],
        ),
      ]),
      _section('Badges and avatars', [
        const Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            StatusBadge.pending(),
            StatusBadge.approved(),
            StatusBadge.rejected(),
            StatusBadge.needsCheck(),
            StatusBadge('Confirmed', icon: AppIcons.verified),
            StatusBadge.simulated(),
            StatusBadge.sandbox(),
            StatusBadge.sample(),
            ComingSoonBadge(),
          ],
        ),
        _gap(),
        const Row(
          children: [
            AppAvatar(name: 'Raka Pratama', tone: AvatarTone.coral),
            SizedBox(width: Space.sm),
            AppAvatar(name: 'Nadia Putri', tone: AvatarTone.teal),
            SizedBox(width: Space.sm),
            AppAvatar(name: 'Dimas Aditya', tone: AvatarTone.blue),
            SizedBox(width: Space.sm),
            AppAvatar(name: 'Salsabila Hanum', tone: AvatarTone.violet),
            SizedBox(width: Space.sm),
            AppAvatar(name: 'Raka Pratama', size: 80),
          ],
        ),
      ]),
      _section('Forms', [
        const AppTextField(
          label: 'UB email',
          hint: 'name@student.ub.ac.id',
          icon: AppIcons.mail,
          keyboardType: TextInputType.emailAddress,
        ),
        _gap(Space.lg),
        OtpField(onChanged: (_) {}),
        _gap(Space.lg),
        SelectField(
          label: 'Course you want to teach',
          value: 'Kalkulus 1',
          onTap: () {},
        ),
        _gap(Space.lg),
        OptionCard(
          title: 'I want to learn',
          subtitle:
              'Get course help from a verified senior. Your first '
              'session with each mentor is free.',
          icon: AppIcons.book,
          selected: _role == 0,
          onTap: () => setState(() => _role = 0),
        ),
        _gap(),
        OptionCard(
          title: 'I want to mentor',
          subtitle: 'Earn in your class gaps by helping juniors in a course you aced.',
          icon: AppIcons.mentor,
          selected: _role == 1,
          onTap: () => setState(() => _role = 1),
        ),
        _gap(),
        OptionCard(
          title: 'Worked examples, step by step',
          compact: true,
          selected: true,
          onTap: () {},
        ),
        _gap(),
        CheckRow(
          value: _agree,
          onChanged: (v) => setState(() => _agree = v),
          label:
              'I won\'t ask my mentor to do graded assignments, '
              'quizzes, or exams for me.',
        ),
        _gap(),
        const StepProgress(current: 1, total: 2),
      ]),
      _section('Cards and notes', [
        MentorMatchCard(data: _sample, onTap: () {}),
        _gap(),
        MentorMatchCard(data: _sample, selected: true, onTap: () {}),
        _gap(),
        const AiReason(
          'You are both free on Tuesday 12:00 to 13:00, and Raka explains '
          'with worked examples, which is how you like to learn.',
          highlighted: true,
        ),
        _gap(),
        const AppCard(
          dashed: true,
          padding: EdgeInsets.symmetric(horizontal: Space.lg, vertical: 12),
          child: Row(
            children: [
              Icon(AppIcons.clock, size: 18, color: AppColors.primaryPressed),
              SizedBox(width: Space.sm),
              Text('Free gap · 50 min'),
            ],
          ),
        ),
        _gap(),
        const AppCard(
          child: Column(
            children: [
              KeyValueRow(
                icon: AppIcons.calendar,
                label: 'Date',
                value: 'Tue, 24 Nov',
              ),
              KeyValueRow(
                icon: AppIcons.clock,
                label: 'Time',
                value: '12:00 to 13:00',
              ),
              KeyValueRow(
                icon: AppIcons.pin,
                label: 'Place',
                value: 'Gedung F, Lt. 2',
              ),
            ],
          ),
        ),
        _gap(),
        const InfoBanner(
          text:
              'Your payment is held by SkillShift and released to Raka '
              'only after you both confirm attendance.',
        ),
        _gap(),
        const InfoBanner(
          tone: BannerTone.info,
          text:
              'Payment stays on hold until you and Raka both tap '
              '"Confirm attendance" after the session.',
        ),
        _gap(),
        const InfoBanner(
          tone: BannerTone.warning,
          text:
              'Payouts are simulated in this prototype. No real money '
              'is transferred yet.',
        ),
        _gap(),
        const InfoBanner(
          tone: BannerTone.neutral,
          text:
              'Stored privately. Only the SkillShift admin can see it, '
              'and only to verify you.',
        ),
      ]),
    ],
  );
}
