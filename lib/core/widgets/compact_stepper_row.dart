import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/compact_step_button.dart';

/// One compact label + stepper row, shared by the flight passenger sheet and
/// the hotel occupancy card.
///
/// The row is the SAME recipe in both selectors (owner decision, 2026-11): the
/// label's typography, the 30dp +/- controls, the 28dp centred value and the
/// spacing. A null [onDecrement] / [onIncrement] renders that control in its
/// disabled state, so a row's minimum or maximum is visible rather than a
/// silent no-op.
///
/// The label is the FIRST child of the row, so the whole row mirrors in RTL
/// exactly as the reading direction does — the minus control stays on the
/// trailing edge and the plus control on the leading edge.
class CompactStepperRow extends StatelessWidget {
  const CompactStepperRow({
    super.key,
    required this.label,
    required this.value,
    this.onDecrement,
    this.onIncrement,
  });

  final String label;
  final int value;

  /// Null at the row's minimum: the minus control renders disabled.
  final VoidCallback? onDecrement;

  /// Null at the row's maximum: the plus control renders disabled.
  final VoidCallback? onIncrement;

  /// The value column's fixed width, identical in both selectors.
  static const double _valueWidth = 28;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final colors = context.tokigoColors;
    return Row(
      textDirection: Directionality.of(context),
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: typography.body.copyWith(color: colors.textPrimary),
          ),
        ),
        CompactStepButton(
          icon: Icons.remove_rounded,
          onTap: onDecrement,
          semanticLabel: 'Decrease $label',
        ),
        SizedBox(
          width: _valueWidth,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: typography.bodyMedium.copyWith(color: colors.textPrimary),
          ),
        ),
        CompactStepButton(
          icon: Icons.add_rounded,
          onTap: onIncrement,
          semanticLabel: 'Increase $label',
        ),
      ],
    );
  }
}
