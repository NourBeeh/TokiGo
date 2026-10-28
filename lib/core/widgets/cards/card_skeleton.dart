import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/shimmer.dart';

/// Wraps a card skeleton so screen readers announce a single label instead of
/// exposing shimmer placeholder internals as real content.
///
/// The [label] is the CALLER's to localize: a hardcoded "Loading" would be
/// English on an Arabic screen. Pass the active language's loading message,
/// or nothing at all when there is no honest one to announce.
Widget cardLoadingSemantics(Widget child, {String? label}) {
  return Semantics(label: label, excludeSemantics: true, child: child);
}

/// Building blocks for card loading skeletons.
///
/// Every approved card's `loading: true` state composes these blocks so the
/// skeleton preserves the exact geometry, spacing and image dimensions of the
/// real card — with NO fake names, prices, destinations, ratings or discounts.
///
/// All blocks are pure [ShimmerBox]s: they contain no text, no icons and no
/// data of any kind.
abstract final class CardSkeleton {
  /// A skeleton line of text.
  static Widget text({double? width, double height = 14}) {
    return ShimmerBox(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(AppRadius.xs),
    );
  }

  /// A skeleton title line (slightly taller, full width).
  static Widget title({double? width, double height = 18}) {
    return ShimmerBox(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(AppRadius.xs),
    );
  }

  /// A skeleton block for a price area.
  static Widget price({double width = 88, double height = 22}) {
    return ShimmerBox(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(AppRadius.xs),
    );
  }

  /// A skeleton chip (feature/badge placeholder).
  static Widget chip({double width = 56, double height = 20}) {
    return ShimmerBox(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    );
  }

  /// A skeleton circular avatar (airline logo placeholder).
  static Widget avatar({double size = 40}) {
    return ShimmerBox(
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
    );
  }

  /// A skeleton image area. Use inside an already-sized box (AspectRatio /
  /// Expanded) — it fills the available space.
  static Widget image() {
    return const SizedBox.expand(
      child: ShimmerBox(borderRadius: BorderRadius.zero),
    );
  }

  /// A fixed-height skeleton image (when the card knows its image height).
  static Widget imageBox({required double height}) {
    return ShimmerBox(height: height, width: double.infinity);
  }

  /// Standard vertical gap between skeleton rows, matching the real card's
  /// rhythm so geometry is preserved.
  static SizedBox gap({double? height = AppSpacing.sm}) {
    return SizedBox(height: height);
  }

  /// Standard horizontal gap between skeleton columns.
  static SizedBox hGap({double? width = AppSpacing.sm}) {
    return SizedBox(width: width);
  }
}
