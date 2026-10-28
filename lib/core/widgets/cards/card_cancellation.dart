import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';

/// Cancellation-policy line: check (free cancellation) or info icon + caption.
class CardCancellation extends StatelessWidget {
  const CardCancellation({
    super.key,
    required this.label,
    this.freeCancellation = false,
    this.style,
  });

  final String label;
  final bool freeCancellation;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          freeCancellation ? Icons.check_circle_outline : Icons.info_outline,
          size: 14,
          color: freeCancellation ? AppColors.success : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                style ??
                Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}
