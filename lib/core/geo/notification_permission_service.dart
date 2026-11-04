import 'package:permission_handler/permission_handler.dart';

/// The outcome of a notification-permission check or request, mirroring the
/// rich [PermissionStatus] set so the UI can explain the true state instead of
/// collapsing everything into a boolean.
enum NotificationAccess {
  /// Permission was granted.
  granted,

  /// Permission was denied (not yet asked).
  denied,

  /// Permission was denied forever — only the system Settings app can change
  /// this. The app must point at that screen and cannot retry.
  deniedForever,

  /// The device/OS does not support notifications (rare, e.g. some watches).
  unavailable;

  /// Map an OS [PermissionStatus] to [NotificationAccess].
  static NotificationAccess fromStatus(PermissionStatus status) =>
      switch (status) {
        PermissionStatus.granted => NotificationAccess.granted,
        PermissionStatus.denied || PermissionStatus.permanentlyDenied =>
          NotificationAccess.deniedForever,
        PermissionStatus.restricted || PermissionStatus.limited =>
          NotificationAccess.deniedForever,
        PermissionStatus.provisional => NotificationAccess.denied,
      };
}

/// One place that talks to the OS notification permission.
///
/// The app asks for notification permission:
///
/// 1. Only after location permission is granted (this is what makes the
///    permission meaningful — the traveller's country was resolved, so a
///    booking-generated reminder is relevant);
/// 2. Only from an explicit, dismissible in-app explainer — never on launch
///    and never from a background path;
/// 3. With the correct message that names what the notifications are for.
///
/// The platform calls are injectable so the mapping is unit-testable without
/// a device.
class NotificationPermissionService {
  NotificationPermissionService({
    required Future<PermissionStatus> Function() status,
    required Future<PermissionStatus> Function() request,
    required bool Function() isSupported,
  })  : _status = status,
        _request = request,
        _isSupported = isSupported;

  final Future<PermissionStatus> Function() _status;
  final Future<PermissionStatus> Function() _request;
  final bool Function() _isSupported;

  /// Current notification permission WITHOUT prompting.
  Future<NotificationAccess> check() async {
    try {
      return NotificationAccess.fromStatus(await _status());
    } catch (_) {
      return NotificationAccess.unavailable;
    }
  }

  /// Ask the OS — only ever called from the user's own tap.
  Future<NotificationAccess> request() async {
    try {
      if (!_isSupported()) return NotificationAccess.unavailable;
      final status = await _request();
      return NotificationAccess.fromStatus(status);
    } catch (_) {
      return NotificationAccess.unavailable;
    }
  }

  /// Open the app's notification settings in the system Settings app.
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
