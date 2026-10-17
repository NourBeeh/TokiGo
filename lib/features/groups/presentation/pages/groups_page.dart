import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Groups tab — trusted group trips (v1 surface with mock content).
///
/// Discovery list of group trips plus a create CTA. Roles, join requests,
/// polls and safety controls arrive with the group detail phase.
class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key});

  static const List<_Group> _groups = <_Group>[
    _Group(
      title: 'Dahab diving week',
      destination: 'Dahab, Egypt',
      membersCount: 6,
      maxMembers: 10,
      dateLabel: 'Oct 12 - 19',
      hue: AppColors.carHue,
    ),
    _Group(
      title: 'Luxor heritage tour',
      destination: 'Luxor, Egypt',
      membersCount: 12,
      maxMembers: 15,
      dateLabel: 'Nov 3 - 7',
      hue: AppColors.hotelHue,
    ),
    _Group(
      title: 'White Desert camp',
      destination: 'Bahariya, Egypt',
      membersCount: 4,
      maxMembers: 8,
      dateLabel: 'Dec 20 - 23',
      hue: AppColors.packageHue,
    ),
    _Group(
      title: 'Cairo weekend walk',
      destination: 'Cairo, Egypt',
      membersCount: 18,
      maxMembers: 25,
      dateLabel: 'Sep 26 - 27',
      hue: AppColors.flightHue,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.groupsTitle,
                      style: typography.display.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.groupsSubtitle,
                      style: typography.body.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverToBoxAdapter(
                child: _CreateGroupCard(onTap: () {}),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              sliver: SliverList.separated(
                itemCount: _groups.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final group = _groups[index];
                  return _GroupCard(
                    title: group.title,
                    destination: group.destination,
                    membersCount: group.membersCount,
                    maxMembers: group.maxMembers,
                    dateLabel: group.dateLabel,
                    hue: group.hue,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateGroupCard extends StatelessWidget {
  const _CreateGroupCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: AppColors.brandContainer,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Create a group trip',
                      style: typography.bodyLargeMedium.copyWith(
                        color: AppColors.onBrandContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Plan together, decide together',
                      style: typography.caption.copyWith(
                        color: AppColors.onBrandContainer.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.onBrandContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.title,
    required this.destination,
    required this.membersCount,
    required this.maxMembers,
    required this.dateLabel,
    required this.hue,
  });

  final String title;
  final String destination;
  final int membersCount;
  final int maxMembers;
  final String dateLabel;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: hue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      size: 20,
                      color: hue,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: typography.bodyLargeMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          destination,
                          style: typography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    dateLabel,
                    style: typography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  _MemberAvatarStack(count: membersCount),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '$membersCount/$maxMembers',
                    style: typography.captionSemibold.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberAvatarStack extends StatelessWidget {
  const _MemberAvatarStack({required this.count});

  final int count;

  static const List<Color> _avatarColors = <Color>[
    AppColors.brand,
    AppColors.accent,
    AppColors.ai,
    AppColors.success,
  ];

  @override
  Widget build(BuildContext context) {
    final shown = count.clamp(1, 4);
    return SizedBox(
      width: 22.0 * shown + 6,
      height: 22,
      child: Stack(
        children: <Widget>[
          for (int i = 0; i < shown; i++)
            PositionedDirectional(
              start: i * 14.0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _avatarColors[i % _avatarColors.length],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _Group {
  const _Group({
    required this.title,
    required this.destination,
    required this.membersCount,
    required this.maxMembers,
    required this.dateLabel,
    required this.hue,
  });

  final String title;
  final String destination;
  final int membersCount;
  final int maxMembers;
  final String dateLabel;
  final Color hue;
}
