import 'package:flutter/material.dart';

import 'package:tokigo/core/widgets/ai_robot_avatar.dart';

/// A subtle TokiGo brand watermark behind the AI chat content.
///
/// The EXISTING brand mark, drawn large and very faint so the conversation
/// stays perfectly readable. Pure decoration: it ignores pointers and is
/// excluded from the semantics tree, so it can never steal a tap or be
/// announced as content.
class AiChatWatermark extends StatelessWidget {
  const AiChatWatermark({super.key, this.opacity = 0.05});

  /// Peak opacity of the watermark. Deliberately tiny — it is a quiet brand
  /// presence, not a background image.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Opacity(
          opacity: opacity,
          child: Image.asset(
            isDark
                ? AiRobotAvatar.darkAssetName
                : AiRobotAvatar.lightAssetName,
            width: 280,
            height: 280,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (context, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
