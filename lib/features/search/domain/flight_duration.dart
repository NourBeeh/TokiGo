/// Formats a flight's elapsed time the way every surface shows it: `5h 25m`,
/// `12h`, `45m`.
///
/// Shared by the result card, the route line and the details page so the three
/// can never disagree about the same flight. The `h`/`m` marks are kept short
/// and language-neutral (the reference design does the same) and the digits stay
/// Latin, matching the numerals used across the app.
String formatFlightDuration(Duration duration) {
  final elapsed = duration.isNegative ? Duration.zero : duration;
  final hours = elapsed.inHours;
  final minutes = elapsed.inMinutes % 60;
  if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
  if (hours > 0) return '${hours}h';
  return '${minutes}m';
}

/// Elapsed time between a departure and an arrival.
String flightDurationBetween(DateTime departure, DateTime arrival) =>
    formatFlightDuration(arrival.difference(departure));
