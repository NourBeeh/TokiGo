import 'package:flutter/material.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/cards/card.dart';

/// Placeholder widget shown when Map view is selected but map is not yet implemented.
class SearchMapPlaceholder extends StatelessWidget {
  const SearchMapPlaceholder({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tc = context.tokigoColors;
    final cs = Theme.of(context).colorScheme;
    final typography = Theme.of(context).brightness == Brightness.dark
        ? AppTypography.forDark()
        : AppTypography.forLight();
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // A decorative glyph, not a status: the neutral on-surface variant.
            Icon(Icons.map_outlined, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppLocalizations.of(context)?.mapViewComingSoon ??
                  'Map view coming soon',
              style: typography.title.copyWith(color: tc.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message ??
                  AppLocalizations.of(context)?.mapIntegrationUnavailable ??
                  'Map integration is not yet available. Results are shown in list view.',
              style: typography.body.copyWith(color: tc.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              CardPrimaryAction(
                label: AppLocalizations.of(context)?.retry ?? 'Retry',
                onPressed: onRetry,
                expanded: false,
                icon: Icons.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
