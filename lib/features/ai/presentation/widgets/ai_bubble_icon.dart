import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';

/// AI assistant icon — Material's built-in robot face.
///
/// Kept as a named widget so call sites stay stable if the artwork is
/// swapped for custom-drawn art again later.
class AiBubbleIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const AiBubbleIcon({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.smart_toy, size: size, color: color ?? AppColors.onBrand);
}
