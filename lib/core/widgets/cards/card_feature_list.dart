import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/cards/card_glass.dart';

/// Row (or wrap) of compact spec chips — the generalized form of CarCard's
/// transmission/seats chips. Theme-aware; pass [onImage] to render frosted
/// pills with white text for placement over a dark photo.
class CardFeatureList extends StatelessWidget {
  const CardFeatureList({
    super.key,
    required this.features,
    this.direction = Axis.horizontal,
    this.emptyWidget = const SizedBox.shrink(),
    this.onImage = false,
  });

  /// Empty/hidden-safe: renders [emptyWidget] when no features exist.
  final List<String> features;
  final Axis direction;
  final Widget emptyWidget;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    if (features.isEmpty) return emptyWidget;

    final scheme = Theme.of(context).colorScheme;

    List<Widget> chips() => [
      for (final feature in features) _chip(context, scheme, feature),
    ];

    if (direction == Axis.vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final chip in chips())
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: chip,
            ),
        ],
      );
    }

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: chips(),
    );
  }

  Widget _chip(BuildContext context, ColorScheme scheme, String feature) {
    final padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xxs,
    );
    final label = Text(
      feature,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: onImage ? Colors.white : scheme.onPrimaryContainer,
      ),
    );

    if (onImage) {
      return CardGlass(
        padding: padding,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: label,
      );
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: label,
    );
  }
}
