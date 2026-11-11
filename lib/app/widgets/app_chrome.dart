import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/features/home/presentation/home_design_tokens.dart';
import 'package:tokigo/features/home/presentation/widgets/home_ai_search_field.dart';

/// The pinned Home AI composer.
///
/// The wordmark row and the service navigation scroll away with the feed; the
/// composer stays pinned at the top of Home so the traveller can always ask
/// the assistant. It belongs to Home only — no other page renders it.
///
/// The band itself is TRANSPARENT: the pill carries the only edge (its halo),
/// so the feed scrolls visibly beneath it and the composer reads as genuinely
/// floating rather than as a solid stripe pinned over the content.
class AppChrome extends StatelessWidget {
  const AppChrome({super.key});

  /// The pinned composer's fixed height: the 56dp pill plus its padding.
  static const double pinnedHeight = 56 + AppSpacing.md * 2;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: SizedBox(
          height: 56,
          child: HomeAiSearchField(
            accentColor: HomeDesignTokens.accentOf(context),
          ),
        ),
      ),
    );
  }
}
