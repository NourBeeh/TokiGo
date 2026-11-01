import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/cards/base_card.dart';
import 'package:tokigo/core/widgets/cards/card_image.dart';

/// A Discover city in the Home rail: the photo alone, with the city's name
/// underneath on the leading edge. The whole tile is the control that opens the
/// city's information page.
class HomeDiscoveryStayCard extends StatelessWidget {
  const HomeDiscoveryStayCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final HomeItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      onTap: onTap,
      enabled: onTap != null,
      showBorder: false,
      showShadow: false,
      padding: EdgeInsets.zero,
      semanticsLabel: item.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: CardImage(
              url: item.imageUrl,
              fit: BoxFit.cover,
              fallbackIcon: Icons.place_rounded,
              semanticLabel: item.title,
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.forLight().bodyLargeMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
