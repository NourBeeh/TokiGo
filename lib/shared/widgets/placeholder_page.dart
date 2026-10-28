import 'package:flutter/material.dart';
import '../../core/navigation/app_route.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ai_entrance_animation.dart';
import '../../core/widgets/page_header.dart';

/// Minimal, generic placeholder used by the router until real feature content
/// is built. Renders the destination label + icon so navigation is usable now.
///
/// Chrome comes from [AppPageHeader] like every other pushed page — this was
/// the last surface still drawing a Material `AppBar` (and therefore the stock
/// back glyph).
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.route, this.subtitle});

  final AppRoute route;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typography = AppTypography.forLight();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: AiEntranceAnimation(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // The body already carries the destination label, so the header
              // contributes the control row alone.
              const AppPageHeader(),
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: AppMotion.normal,
                    switchInCurve: AppMotion.standard,
                    child: Column(
                      key: ValueKey<String>(route.name),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            route.filledIcon,
                            size: 44,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          route.label,
                          style: typography.title.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle ?? 'This screen arrives in a later phase.',
                          textAlign: TextAlign.center,
                          style: typography.body.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'TokiGo • Phase 1 Foundation',
                          style: typography.label.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
