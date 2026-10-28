/// One entry of the notifications feed.
///
/// The feed is DATA, not copy: a notification exists because a real event
/// happened (a booking update, a price alert, a check-in reminder). Nothing
/// in the app fabricates one — the surface stays empty until a backend or a
/// push service really delivers something.
///
/// The timestamp is real as well: it decides which group header the entry
/// sits under ("Today" / "Earlier") and what the end-of-row time reads.
final class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.unread = true,
  });

  /// Stable identity of the event (the backend's own id).
  final String id;

  /// The headline — one line, 17/600.
  final String title;

  /// The detail line — up to two lines, 13/400.
  final String body;

  /// When the event happened.
  final DateTime timestamp;

  /// Whether the entry still carries the unread marker.
  final bool unread;
}
