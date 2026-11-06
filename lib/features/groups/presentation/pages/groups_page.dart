import 'package:flutter/material.dart';

import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/widgets/pressable.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Groups tab — trusted group trips.
///
/// **OWNER DECISION (2026-10-19): no fabricated content.** v1 listed four
/// invented group trips (invented member counts, dates and destinations) plus a
/// "create" card that did nothing. The list is empty until real group trips
/// exist (roles, join requests, polls and safety controls arrive with the group
/// backend phase), and the surface says so instead of showing a fake feed.
class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key, this.bottomPadding = 0});

  /// Extra space reserved under the scroll content, e.g. Home's floating AI
  /// composer, so the last card is never hidden behind it.
  final double bottomPadding;

  /// Empty by design (see the class doc).
  static const List<_Group> _groups = <_Group>[];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.tokigoColors.background,
      body: SafeArea(
        child: AiEntranceAnimation(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: AppPageHeader(
                  subtitle: l10n.groupsSubtitle,
                ),
              ),
              if (_groups.isEmpty)
                SliverToBoxAdapter(
                  child: AppMessageState(
                    icon: Icons.diversity_3_outlined,
                    title: l10n.groupsEmptyTitle,
                    body: l10n.groupsEmptyBody,
                  ),
                )
              else ...<Widget>[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
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
                    separatorBuilder: (_, _) =>
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
              if (bottomPadding > 0)
                SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
            ],
          ),
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

    return Pressable.wrap(
      child: Material(
        color: context.tokigoColors.brandContainer,
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
                decoration: BoxDecoration(
                  color: context.tokigoColors.brand,
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
                      AppLocalizations.of(context)?.groupsCreateTrip ??
                          'Create a group trip',
                      style: typography.bodyLargeMedium.copyWith(
                        color: context.tokigoColors.onBrandContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      AppLocalizations.of(context)?.groupsPlanTogether ??
                          'Plan together, decide together',
                      style: typography.caption.copyWith(
                        color: context.tokigoColors.onBrandContainer.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.tokigoColors.onBrandContainer,
              ),
            ],
          ),
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

    return Pressable.wrap(
      child: Material(
        color: context.tokigoColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {},
          child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: context.tokigoColors.outline),
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
                    child: Icon(Icons.groups_rounded, size: 20, color: hue),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: typography.bodyLargeMedium.copyWith(
                            color: context.tokigoColors.textPrimary,
                          ),
                        ),
                        Text(
                          destination,
                          style: typography.caption.copyWith(
                            color: context.tokigoColors.textTertiary,
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
                    color: context.tokigoColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    dateLabel,
                    style: typography.caption.copyWith(
                      color: context.tokigoColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  _MemberAvatarStack(count: membersCount),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '$membersCount/$maxMembers',
                    style: typography.captionSemibold.copyWith(
                      color: context.tokigoColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
    AppColors.ink,
    AppColors.classStar,
    AppColors.textSecondary,
    AppColors.textPrimary,
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
                      fontSize: AppTypography.fontSizeLabel,
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
