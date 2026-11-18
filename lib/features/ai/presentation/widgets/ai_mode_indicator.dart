import 'package:flutter/material.dart';
import 'package:tokigo/l10n/app_localizations.dart';

import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/tokigo_gradients.dart';
import 'package:tokigo/core/theme/app_elevation.dart';

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
    final tc = context.tokigoColors;
    return Semantics(
      label: AppLocalizations.of(context)?.aiModeActive ?? 'AI mode active',
      image: true,
      child: Container(
        width: dimension,
        height: dimension,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: TokiGoGradients.brandGradient(),
          boxShadow: AppElevation.shadow(
            background: tc.surface,
            level: AppElevation.sm,
          ),
        ),
        child: Icon(
          Icons.auto_awesome,
          size: dimension * 0.45,
          color: tc.onMedia,
        ),
      ),
    );
  }
}
