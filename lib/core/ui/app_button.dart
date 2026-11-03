import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';

/// Visual variant of the unified button kit.
enum AppButtonType {
  /// Solid brand fill — the single primary action of a surface.
  primary,

  /// Tinted brand fill (8% alpha) with primary text — secondary actions.
  secondary,

  /// Text-only button — tertiary/inline actions.
  ghost,

  /// Solid danger fill — destructive actions.
  destructive,

  /// White fill with a 1px outline, fully rounded — the "See all N" style
  /// secondary action that sits under a list. Fixed 48 tall, 17/600, so it
  /// reads as a quiet sibling of [primary] rather than a tinted copy.
  pillOutline,
}

/// Size preset of the unified button kit.
enum AppButtonSize { sm, md, lg }

/// The unified button kit for the entire app ("Solid Minimal").
///
/// One height (52), one radius (14), one typography scale. Press feedback is
/// a quiet shade swap plus a light haptic — no gradients, no elevation.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.expanded = true,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool expanded;
  final String? semanticLabel;

  double get _height {
    // The pill is a single, fixed control: 48 tall so it clears the minimum
    // touch target on its own, whatever size the caller passes.
    if (type == AppButtonType.pillOutline) return 48;
    return switch (size) {
      AppButtonSize.sm => 40,
      AppButtonSize.md => 52,
      AppButtonSize.lg => 56,
    };
  }

  BorderRadius get _radius => type == AppButtonType.pillOutline
      ? AppRadius.pillBorder
      : BorderRadius.circular(AppRadius.md);

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final typography = Theme.of(context).brightness == Brightness.dark
        ? AppTypography.forDark()
        : AppTypography.forLight();
    final Color foreground;
    final Color baseBackground;

    switch (type) {
      case AppButtonType.primary:
        foreground = context.tokigoColors.onBrand;
        baseBackground = disabled
            ? context.tokigoColors.surfaceTertiary
            : context.tokigoColors.brand;
      case AppButtonType.secondary:
        foreground = disabled
            ? context.tokigoColors.textTertiary
            : context.tokigoColors.brand;
        baseBackground = disabled
            ? context.tokigoColors.surfaceTertiary
            : context.tokigoColors.surface;
      case AppButtonType.ghost:
        foreground = disabled
            ? context.tokigoColors.textTertiary
            : context.tokigoColors.brand;
        baseBackground = Colors.transparent;
      case AppButtonType.destructive:
        foreground = Colors.white;
        baseBackground = disabled
            ? context.tokigoColors.surfaceTertiary
            : context.tokigoColors.danger;
      case AppButtonType.pillOutline:
        foreground = disabled
            ? context.tokigoColors.textTertiary
            : context.tokigoColors.textPrimary;
        baseBackground = context.tokigoColors.surface;
    }

    final disabledForeground =
        type == AppButtonType.primary || type == AppButtonType.destructive
        ? context.tokigoColors.textTertiary
        : foreground;

    final textStyle =
        (size == AppButtonSize.sm && type != AppButtonType.pillOutline
                ? typography.bodyMedium
                : typography.bodyLargeMedium)
            .copyWith(color: disabled ? disabledForeground : foreground);

    bool pressed = false;
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        final Color background = pressed && !disabled
            ? Color.lerp(baseBackground, foreground, 0.08)!
            : baseBackground;
        return Semantics(
          button: true,
          enabled: !disabled,
          label: semanticLabel ?? label,
          child: AnimatedScale(
            scale: pressed && !disabled ? 0.98 : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: Material(
              color: background,
              borderRadius: _radius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onHighlightChanged: disabled
                    ? null
                    : (bool value) {
                        if (pressed != value) {
                          setState(() => pressed = value);
                        }
                      },
                onTap: disabled
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        onPressed!();
                      },
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                child: Container(
                  height: _height,
                  constraints: expanded
                      ? null
                      : const BoxConstraints(minWidth: 64),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  decoration:
                      type == AppButtonType.pillOutline ||
                          type == AppButtonType.secondary
                      ? BoxDecoration(
                          border: Border.all(
                            color: context.tokigoColors.hairlineStrong,
                          ),
                          borderRadius: _radius,
                        )
                      : null,
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      // Only an expanded button in a bounded width needs to give
                      // the label room to shrink; in an unbounded horizontal
                      // context (a scrollable row) a flex child is illegal, and
                      // the button correctly shrink-wraps instead.
                      final bool flexibleLabel =
                          expanded && constraints.hasBoundedWidth;
                      final Widget labelText = Text(
                        label,
                        style: textStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      );
                      return Row(
                        mainAxisSize: expanded
                            ? MainAxisSize.max
                            : MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          if (leadingIcon != null) ...<Widget>[
                            Icon(leadingIcon, size: 20, color: textStyle.color),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          if (flexibleLabel)
                            Flexible(child: labelText)
                          else
                            labelText,
                          if (trailingIcon != null) ...<Widget>[
                            const SizedBox(width: AppSpacing.sm),
                            Icon(
                              trailingIcon,
                              size: 20,
                              color: textStyle.color,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
