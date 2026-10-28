/// Shared card design system for B&GO.
///
/// Compose these primitives inside [BaseCard]; feature cards (Hotel/Flight/
/// Car/...) wire them to their models — the system itself stays model-free.
library;

import 'card_image.dart';

export 'base_card.dart';
export 'booking_status_card.dart';
export 'card_availability.dart';
export 'card_badge.dart';
export 'card_cancellation.dart';
export 'card_favorite.dart';
export 'card_feature_list.dart';
export 'card_glass.dart';
export 'card_image.dart';
export 'card_location.dart';
export 'card_overlap.dart';
export 'card_price.dart';
export 'card_price_block.dart';
export 'card_primary_action.dart';
export 'card_rating.dart';
export 'card_scrim_overlay.dart';
export 'card_skeleton.dart';
export 'discover_badge_card.dart';
export 'hero_sheet.dart';
export 'overlap_stay_card.dart';
export 'photo_counter_chip.dart';
export 'photo_pager_dots.dart';
export 'rating_badge.dart';

/// New badge system exports
export 'badge_config.dart';

/// Deal presentation exports
export 'deal_presentation.dart';

/// Canonical media alias: [CardMedia] is the shared-system name for the
/// existing, battle-tested [CardImage] (kept as-is so existing card APIs
/// remain untouched).
typedef CardMedia = CardImage;
