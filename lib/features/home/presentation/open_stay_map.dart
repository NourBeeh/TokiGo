import 'package:url_launcher/url_launcher.dart';

/// Opens a stay's location in the platform's map application (Google Maps in
/// the browser when no map app is installed).
///
/// Coordinates are preferred when the provider sent them; otherwise the hotel
/// name plus the location line is a real, searchable query — no address is
/// invented.
Future<void> openStayInMaps({
  required String name,
  required String location,
  double? latitude,
  double? longitude,
}) async {
  final String query = latitude != null && longitude != null
      ? '$latitude,$longitude'
      : <String>[
          name.trim(),
          location.trim(),
        ].where((String part) => part.isNotEmpty).join(', ');
  if (query.isEmpty) return;

  final Uri uri = Uri.https('www.google.com', '/maps/search/', <String, String>{
    'api': '1',
    'query': query,
  });
  try {
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  } catch (_) {
    // A device without a map/browser cannot open the link; the card itself
    // still works, so failing silently is the honest behaviour here.
  }
}
