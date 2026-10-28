import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_elevation.dart';
import 'package:tokigo/core/theme/app_motion.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';

/// Destination of the floating bottom navigation bar.
enum AppBottomNavDestination {
  home(Icons.home_outlined, Icons.home_rounded),
  search(Icons.search, Icons.search_rounded),
  groups(Icons.groups_outlined, Icons.groups_rounded),
  explore(Icons.explore_outlined, Icons.explore_rounded);

  const AppBottomNavDestination(this.icon, this.selectedIcon);

  final IconData? icon;
  final IconData? selectedIcon;
}

/// The unified floating bottom navigation bar.
///
/// Four tabs on a detached pill surface hovering above the page content:
/// rounded corners, a soft diffused shadow and a bottom margin so the feed
/// scrolls underneath. Tabs animate with a quiet scale + colour ramp; layout
/// mirrors automatically under RTL.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.current,
    required this.onSelect,
  });

  /// Currently highlighted destination.
  final AppBottomNavDestination current;

  /// Fires with the selected tab destination.
  final ValueChanged<AppBottomNavDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.xlBorder,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: AppElevation.shadow(
          background: scheme.surface,
          level: AppElevation.lg,
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final destination in AppBottomNavDestination.values)
                Expanded(
                  child: _NavItem(
                    destination: destination,
                    selected: current == destination,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelect(destination);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : AppColors.textTertiary;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        splashFactory: NoSplash.splashFactory,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1,
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              child: Icon(
                (selected ? destination.selectedIcon : destination.icon) ??
                    Icons.error_outline,
                size: 24,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                height: 1,
              ),
              child: Text(
                destination.name[0].toUpperCase() +
                    destination.name.substring(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
