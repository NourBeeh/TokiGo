import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_spacing.dart';

/// One-line location row: pin icon + text, ellipsized.
class CardLocation extends StatelessWidget {
  const CardLocation({
    super.key,
    required this.text,
    this.icon = Icons.location_on_outlined,
    this.style,
    this.maxLines = 1,
  });

  final String text;
  final IconData icon;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style:
                style ??
                Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
