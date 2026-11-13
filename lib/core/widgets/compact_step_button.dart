import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/pressable.dart';

/// A small square stepper button for compact selector cards.
///
/// ONE shape everywhere a count is edited — the flight passenger sheet and the
/// hotel occupancy card — so the two selectors read as the same control
/// (owner decision, 2026-11). The fill and ink are the shared brand tokens;
/// no surface-specific colours.
///
/// A null [onTap] is a DISABLED button: it keeps the exact same geometry but
/// drops to the tertiary fill and muted ink, and it never reacts to a tap or a
/// press. Callers pass null at a row's minimum/maximum so the constraint is
/// visible on screen instead of being a silent no-op.
class CompactStepButton extends StatelessWidget {
  const CompactStepButton({
    super.key,
    required this.icon,
    this.onTap,
    this.semanticLabel,
  });

  final IconData icon;

  /// The tap action. Null renders the disabled state.
  final VoidCallback? onTap;

  /// Optional accessible name. When provided the control is announced once
  /// with this label and the inner Material button's own semantics are
  /// excluded, so a screen reader hears one button rather than two.
  final String? semanticLabel;

  bool get _enabled => onTap != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokigoColors;
    final Widget button = Pressable.wrap(
      enabled: _enabled,
      child: Material(
        color: _enabled ? colors.brandContainer : colors.surfaceTertiary,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(
              icon,
              size: 18,
              color: _enabled ? colors.brand : colors.textTertiary,
            ),
          ),
        ),
      ),
    );

    final String? label = semanticLabel;
    if (label == null) return button;
    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(child: button),
    );
  }
}
