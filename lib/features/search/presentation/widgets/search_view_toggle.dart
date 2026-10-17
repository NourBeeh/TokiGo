import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/features/search/application/providers/search_view_providers.dart';
import 'package:tokigo/features/search/domain/search_view_mode.dart';

/// Segmented control for toggling between List and Map view modes.
class SearchViewToggle extends ConsumerWidget {
  const SearchViewToggle({super.key, this.tooltip = 'Toggle view mode'});

  final String? tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(searchViewModeProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Semantics(
      label: 'View mode: ${mode.label}. Double tap to toggle.',
      button: true,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Card(
          color: cs.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
          child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Segment(
              label: 'List',
              icon: Icons.list,
              isSelected: mode == SearchViewMode.list,
              onTap: () => ref.read(searchViewModeProvider.notifier).state = SearchViewMode.list,
            ),
            _Segment(
              label: 'Map',
              icon: Icons.map,
              isSelected: mode == SearchViewMode.map,
              onTap: () => ref.read(searchViewModeProvider.notifier).state = SearchViewMode.map,
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Intrinsic width (no Expanded): the toggle renders inside app-bar
    // actions where width constraints can be unbounded.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill - 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill - 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? cs.onPrimary : cs.onSurfaceVariant),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}