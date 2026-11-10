import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/tokigo_gradients.dart';
import 'package:tokigo/core/widgets/pressable.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// A compact "Ask your assistant" entry point for non-Home pages.
///
/// It appears only where manual search results are displayed (the flight and
/// hotel results pages), hands the existing AI chat route a useful prompt
/// built from the current search, and stays out of the way of the results.
///
/// It is deliberately NOT a full search box: Home owns the composer, and every
/// other page gets this one unobtrusive card.
class AskAssistantCard extends StatelessWidget {
  const AskAssistantCard({super.key, required this.prompt, this.onTap});

  /// The natural-language prompt handed to the AI chat route.
  final String prompt;

  /// Optional tap handler. Defaults to pushing the existing `/ai-chat` route
  /// with [prompt] as its initial query.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tc = context.tokigoColors;
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    return Pressable.wrap(
      child: Material(
        color: tc.brandContainer,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdBorder,
          side: BorderSide(color: tc.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap ?? () => context.push('/ai-chat', extra: prompt),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: TokiGoGradients.brandGradient(),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(
                    width: 30,
                    height: 30,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        l10n.askAssistantTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.bodyMedium.copyWith(
                          color: tc.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.askAssistantSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.caption.copyWith(
                          color: tc.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: tc.brand,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
