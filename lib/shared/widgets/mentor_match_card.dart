import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import 'badges.dart';
import 'surfaces.dart';

/// Data shown on a match card. Filled by the `match-mentors` Edge Function.
class MentorMatchData {
  const MentorMatchData({
    required this.mentorId,
    required this.name,
    required this.program,
    required this.cohortYear,
    required this.proof,
    required this.reason,
    required this.slotLabel,
    required this.pricePerHour,
    this.firstSessionFree = true,
  });

  final String mentorId;
  final String name;
  final String program;
  final int cohortYear;

  /// "A in Kalkulus 1" or "GPA 3.85".
  final String proof;

  /// One-line AI (or fallback) explanation.
  final String reason;

  /// "Tue 12:00 to 13:00".
  final String slotLabel;
  final int pricePerHour;
  final bool firstSessionFree;
}

/// Figma `Card/Mentor Match`.
class MentorMatchCard extends StatelessWidget {
  const MentorMatchCard({
    super.key,
    required this.data,
    this.onTap,
    this.selected = false,
  });

  final MentorMatchData data;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    selected: selected,
    color: AppColors.surface,
    padding: const EdgeInsets.all(Space.lg + 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppAvatar(name: data.name, size: 48),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          data.name,
                          style: AppText.h3.copyWith(fontSize: 17),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        AppIcons.verified,
                        size: 18,
                        color: AppColors.primary,
                        semanticLabel: 'Verified mentor',
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${data.program} ${data.cohortYear} · ${data.proof}',
                    style: AppText.small.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        AiReason(data.reason),
        const SizedBox(height: Space.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: Radii.rSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      AppIcons.clock,
                      size: 15,
                      color: AppColors.primaryPressed,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        data.slotLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.smallMedium.copyWith(
                          color: AppColors.primaryPressed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Space.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${formatRupiah(data.pricePerHour)}/hr',
                  style: AppText.h3.copyWith(fontSize: 17),
                ),
                if (data.firstSessionFree)
                  Text(
                    '1st session free',
                    style: AppText.caption.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}
