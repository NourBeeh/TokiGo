import 'package:flutter/foundation.dart';

/// The deliberately different overlaps of the "Warm Editorial" card system.
///
/// Both are the distance an info sheet rides up over the photo above it. They
/// are NOT the same number and must never be collapsed into one constant: a
/// results card tucks a 48px sheet over a 4:3 photo to make one compact object,
/// while an offer-detail page keeps its hero photo dominant and lets the sheet
/// only bite 24px into it.
@immutable
abstract final class AppOverlap {
  /// Results card (archetype A): photo + sheet, sheet rides 48px up.
  static const double card = 48;

  /// Offer-details hero (archetype G): a 24px bite only.
  static const double detailSheet = 24;
}
