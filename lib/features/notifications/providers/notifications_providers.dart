import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/features/notifications/domain/app_notification.dart';

/// The live notifications feed.
///
/// There is deliberately NO fabricated seed: the list stays empty until a real
/// backend/push integration delivers an [AppNotification]. That integration is
/// the only writer — Home's bell and the notifications page both read from
/// here, so they can never disagree about what is new or unread.
final notificationsProvider = StateProvider<List<AppNotification>>(
  (ref) => const <AppNotification>[],
);

/// Number of entries still carrying the unread marker.
///
/// Derived from [notificationsProvider] rather than stored separately: a badge
/// can never drift out of sync with the feed, and marking an entry read is a
/// single update to the feed itself.
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref
      .watch(notificationsProvider)
      .where((AppNotification notification) => notification.unread)
      .length;
});
