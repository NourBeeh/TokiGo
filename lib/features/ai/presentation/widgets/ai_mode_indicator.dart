import 'package:flutter/material.dart';
import 'package:tokigo/l10n/app_localizations.dart';

import 'package:tokigo/core/theme/app_colors.dart';

/// Circular brand indicator identifying the active AI mode.
///
/// This is the reserved slot where the single circular AI/Normal toggle
/// button mounts in a later phase. Today it is a purely static indicator —
/// no interaction and no mode logic.
class AiModeIndicator extends StatelessWidget {
  const AiModeIndicator({super.key, this.dimension = 40});

  final double dimension;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: AppLocalizations.of(context)?.aiModeActive ?? 'AI mode active',
      image: true,
      child: Container(
        width: dimension,
        height: dimension,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppColors.ai, AppColors.aiLight],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.ai.withValues(alpha: 0.30),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.auto_awesome,
          size: dimension * 0.45,
          color: scheme.onPrimary,
        ),
      ),
    );
  }
}
