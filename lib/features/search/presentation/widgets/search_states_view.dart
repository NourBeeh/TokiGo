import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The unified search results state surface (Wave 2 identity).
///
/// Every vertical renders idle/loading/empty/error through this one widget
/// with the same rich premium design — no more bare centered text.
class SearchStatesView extends StatelessWidget {
  const SearchStatesView.idle({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  }) : _state = _SearchState.idle,
       skeleton = null;

  const SearchStatesView.loading({super.key, required this.skeleton})
    : icon = null,
      title = null,
      body = null,
      actionLabel = null,
      onAction = null,
      _state = _SearchState.loading;

  const SearchStatesView.empty({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  }) : _state = _SearchState.empty,
       skeleton = null;

  const SearchStatesView.error({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  }) : _state = _SearchState.error,
       icon = Icons.wifi_off_rounded,
       skeleton = null;

  final _SearchState _state;

  /// Skeleton list shown while loading.
  final Widget? skeleton;

  final IconData? icon;
  final String? title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _SearchState.loading:
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: <Widget>[for (int i = 0; i < 5; i++) skeleton!],
          ),
        );
      case _SearchState.idle:
      case _SearchState.empty:
      case _SearchState.error:
        final l10n = AppLocalizations.of(context);
        // The shared honest-state recipe (`lib/core/ui/app_message_state.dart`)
        // — one look for "no data" across the whole app.
        return AppMessageState(
          icon: _state == _SearchState.error
              ? Icons.wifi_off_rounded
              : icon ?? Icons.travel_explore_rounded,
          hue: _state == _SearchState.error
              ? AppColors.danger
              : AppColors.brand,
          title: title ?? '',
          body: body ?? '',
          actionLabel: onAction != null
              ? (actionLabel ??
                    (_state == _SearchState.error
                        ? (l10n?.retry ?? 'Retry')
                        : (l10n?.viewAll ?? 'View all')))
              : null,
          onAction: onAction,
        );
    }
  }
}

enum _SearchState { idle, loading, empty, error }

/// Horizontal sort chips row (replaces the dropdown) + filter button.
///
/// Generic over the option type so a vertical can pass enum values and a
/// localized [labelOf], instead of comparing localized display strings.
class SortChipsRow<T> extends StatelessWidget {
  const SortChipsRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.labelOf,
    this.filtersLabel,
    this.filtersActive = false,
    this.onFilters,
    this.iconOf,
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Renders one option's display label. Defaults to `toString()` (plain
  /// string options keep working unchanged).
  final String Function(T)? labelOf;

  final String? filtersLabel;
  final bool filtersActive;
  final VoidCallback? onFilters;

  /// Optional leading glyph per option (a Material icon — the bundled fonts
  /// have no star character, so a text glyph would render as tofu).
  final IconData? Function(T)? iconOf;

  @override
  Widget build(BuildContext context) {
    // The fade sits at the trailing edge; resolved here because the shader
    // callback runs at paint time, outside the Directionality scope.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final fadeBegin = isRtl ? Alignment.centerRight : Alignment.centerLeft;
    final fadeEnd = isRtl ? Alignment.centerLeft : Alignment.centerRight;
    return SizedBox(
      height: 48,
      child: Row(
        children: <Widget>[
          Expanded(
            // The chips scroll under a fade at the trailing edge, so a
            // half-visible option reads as "more to scroll" instead of a
            // clipped layout.
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (Rect bounds) => LinearGradient(
                begin: fadeBegin,
                end: fadeEnd,
                // Only the alpha matters for a dstIn mask.
                colors: const <Color>[
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: const <double>[0, 0.78, 1],
              ).createShader(bounds),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  return _SortChip(
                    label: labelOf?.call(option) ?? option.toString(),
                    icon: iconOf?.call(option),
                    selected: option == selected,
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
          if (onFilters != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.sm,
                end: AppSpacing.lg,
              ),
              child: _FilterButton(
                label: filtersLabel ?? 'Filters',
                active: filtersActive,
                onTap: onFilters!,
              ),
            ),
        ],
      ),
    );
  }
}

/// One chip in a [SortChipsRow] — the shared pill recipe.
class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Optional leading glyph (a Material icon — the bundled fonts have no
  /// star character, so a text glyph would render as tofu).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final foreground = selected ? Colors.white : AppColors.textSecondary;
    final icon = this.icon;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Material(
        color: selected ? AppColors.brand : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: selected ? AppColors.brand : AppColors.outline,
              ),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 14, color: foreground),
                    const SizedBox(width: AppSpacing.xxs),
                  ],
                  Text(
                    label,
                    style: typography.captionSemibold.copyWith(
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Material(
        color: active ? AppColors.brandContainer : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: active ? AppColors.brand : AppColors.outline,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: active ? AppColors.brand : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: typography.captionSemibold.copyWith(
                    color: active ? AppColors.brand : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
