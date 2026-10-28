import 'package:flutter/foundation.dart';

/// The app's reachability of the backend, as the **data layer** sees it.
///
/// This is not a guess from the radio: it is what the API client reports after
/// every call. A transport failure (no socket, no host, a timeout) means the
/// backend cannot be reached right now; any successful call means it can.
///
/// The app shows this as a slim banner so the traveller always knows whether
/// the content on screen is live or the last thing the app managed to save.
class NetworkStatus extends ChangeNotifier {
  NetworkStatus._();

  /// The one instance the app and the API client share.
  static final NetworkStatus instance = NetworkStatus._();

  bool _online = true;
  bool _announcedOffline = false;

  /// Whether the last call reached the backend.
  bool get online => _online;

  /// The backend could not be reached. Called by the API client.
  void reportOffline() {
    if (!_online) return;
    _online = false;
    _announcedOffline = true;
    notifyListeners();
  }

  /// The backend answered (or answered with an HTTP error — it is reachable).
  void reportOnline() {
    if (_online) return;
    _online = true;
    _announcedOffline = false;
    notifyListeners();
  }

  /// Whether the app has already told the traveller the connection is down.
  /// The banner uses it to stay quiet until there is something to say.
  bool get announcedOffline => _announcedOffline;
}
