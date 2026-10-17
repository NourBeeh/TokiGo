import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';

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
  })  : _state = _SearchState.idle,
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
  })  : _state = _SearchState.empty,
        skeleton = null;

  const SearchStatesView.error({
    super.key,
    required this.title,
    required this.body,
    this.onAction,
  })  : _state = _SearchState.error,
        icon = Icons.wifi_off_rounded,
        skeleton = null,
        actionLabel = null;

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
          child: Column(children: <Widget>[for (int i = 0; i < 5; i++) skeleton!]),
        );
      case _SearchState.idle:
      case _SearchState.empty:
      case _SearchState.error:
        return _MessageState(
          icon: _state == _SearchState.error
              ? Icons.wifi_off_rounded
              : icon ?? Icons.travel_explore_rounded,
          hue: _state == _SearchState.error ? AppColors.danger : AppColors.brand,
          title: title ?? '',
          body: body ?? '',
          actionLabel: onAction != null
              ? (actionLabel ??
                  (_state == _SearchState.error ? 'Retry' : 'Explore'))
              : null,
          onAction: onAction,
        );
    }
  }
}

enum _SearchState { idle, loading, empty, error }

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.hue,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color hue;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxxl,
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: hue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: hue),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: typography.title.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: typography.body.copyWith(color: AppColors.textSecondary),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: actionLabel!,
              type: AppButtonType.secondary,
              expanded: false,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

/// Horizontal sort chips row (replaces the dropdown) + filter button.
class SortChipsRow extends StatelessWidget {
  const SortChipsRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.filtersLabel,
    this.filtersActive = false,
    this.onFilters,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final String? filtersLabel;
  final bool filtersActive;
  final VoidCallback? onFilters;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: <Widget>[
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = option == selected;
                return _SortChip(
                  label: option,
                  selected: isSelected,
                  onTap: () => onSelected(option),
                );
              },
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

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
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
              child: Text(
                label,
                style: typography.captionSemibold.copyWith(
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
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
