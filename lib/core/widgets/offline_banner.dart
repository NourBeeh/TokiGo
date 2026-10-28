import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The "the connection is cut" strip.
///
/// It sits under the status bar on **every** page, and it is only there when
/// the data layer really could not reach the backend — the app does not guess
/// from the radio. While it is up, the content on screen is the last data the
/// app managed to save (the Hive cache), so the traveller is told exactly
/// what they are looking at.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typography = AppTypography.forLight();
    return Container(
      width: double.infinity,
      color: AppColors.warningContainer,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.wifi_off_rounded,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.offlineShowingCached,
              style: typography.caption.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}
