import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';

/// Section heading used inside the details sheet.
///
/// Takes the typography set from the caller so every section on the page shares
/// one text theme instead of re-resolving it per widget.
class OfferDetailsSectionTitle extends StatelessWidget {
  const OfferDetailsSectionTitle({
    super.key,
    required this.typography,
    required this.title,
  });

  final AppTypography typography;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        title,
        style: typography.title.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}
