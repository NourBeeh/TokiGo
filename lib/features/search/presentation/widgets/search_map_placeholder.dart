import 'package:flutter/material.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/cards/card.dart';

/// Placeholder widget shown when Map view is selected but map is not yet implemented.
class SearchMapPlaceholder extends StatelessWidget {
  const SearchMapPlaceholder({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: cs.primary.withValues(alpha: 0.3)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Map view coming soon',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message ?? 'Map integration is not yet available. Results are shown in list view.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              CardPrimaryAction(
                label: 'Retry',
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