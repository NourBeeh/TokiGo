import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/features/home/presentation/home_design_tokens.dart';
import 'package:tokigo/features/home/presentation/widgets/home_ai_search_field.dart';

/// The Home AI composer — the original search box.
///
/// It is part of the scrollable Home header: the wordmark, this composer and
/// the service navigation all leave the viewport together as the feed scrolls.
/// It belongs to Home only — no other page renders it.
///
/// The band itself is TRANSPARENT: the pill carries the only edge (its halo),
/// so it reads as a floating pill rather than a solid stripe.
class AppChrome extends StatelessWidget {
  const AppChrome({super.key, this.controller});

  /// Optional lifted text controller, so the composer's draft survives the
  /// header being scrolled out of the viewport and back.
  final TextEditingController? controller;

  /// The pinned composer's fixed height: the pill plus its padding.
  static const double pinnedHeight =
      HomeAiSearchField.height + AppSpacing.md * 2;

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
          height: HomeAiSearchField.height,
          child: HomeAiSearchField(
            controller: controller,
            accentColor: HomeDesignTokens.accentOf(context),
          ),
        ),
      ),
    );
  }
}
