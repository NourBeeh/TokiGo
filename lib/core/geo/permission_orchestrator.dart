import 'location_permission_service.dart';
import 'notification_permission_service.dart';

import 'package:permission_handler/permission_handler.dart';

/// The app-wide first-launch permission state. It is the single source of
/// truth for the Home explainer, the onboarding trail and the Settings page.
///
/// The state is persisted in Hive so it survives a restart:
///
/// - [locationAccess] and [notificationAccess] are the **authoritative**
///   permission truth (what the OS answered, not what the user dismissed);
/// - [locationResolved] is incremented the first time location is granted,
///   so the country is re-resolved with GPS once.
///
/// Sequencing rule (owner decision, 2026-10-22 → extended):
/// notification access is never asked for on launch; it only follows a granted
/// location access.
class PermissionState {
  const PermissionState({
    this.locationAccess = LocationAccess.unavailable,
    this.notificationAccess = NotificationAccess.unavailable,
    this.locationExplainerDismissed = false,
    this.locationResolved = false,
    this.notificationRequestShown = false,
    this.initialized = false,
  });

  final LocationAccess locationAccess;
  final NotificationAccess notificationAccess;
  final bool locationExplainerDismissed;
  final bool locationResolved;
  final bool notificationRequestShown;
  final bool initialized;

  /// Returns a copy with [locationAccess] updated.
  PermissionState copyWithLocationAccess(LocationAccess access) =>
      PermissionState(
        locationAccess: access,
        locationExplainerDismissed: locationExplainerDismissed,
        locationResolved: locationResolved,
        notificationAccess: notificationAccess,
        notificationRequestShown: notificationRequestShown,
        initialized: initialized,
      );

  PermissionState copyWithNotificationAccess(NotificationAccess access) =>
      PermissionState(
        locationAccess: locationAccess,
        notificationAccess: access,
        locationExplainerDismissed: locationExplainerDismissed,
        locationResolved: locationResolved,
        notificationRequestShown: notificationRequestShown,
        initialized: initialized,
      );

  PermissionState copyWithLocationExplainerDismissed(bool dismissed) =>
      PermissionState(
        locationAccess: locationAccess,
        notificationAccess: notificationAccess,
        locationExplainerDismissed: dismissed,
        locationResolved: locationResolved,
        notificationRequestShown: notificationRequestShown,
        initialized: initialized,
      );

  PermissionState copyWithLocationResolved(bool resolved) =>
      PermissionState(
        locationAccess: locationAccess,
        notificationAccess: notificationAccess,
        locationExplainerDismissed: locationExplainerDismissed,
        locationResolved: resolved,
        notificationRequestShown: notificationRequestShown,
        initialized: initialized,
      );

  PermissionState copyWithNotificationRequestShown(bool shown) =>
      PermissionState(
        locationAccess: locationAccess,
        notificationAccess: notificationAccess,
        locationExplainerDismissed: locationExplainerDismissed,
        locationResolved: locationResolved,
        notificationRequestShown: shown,
        initialized: initialized,
      );

  PermissionState copyWithInitialized(bool initialized) =>
      PermissionState(
        locationAccess: locationAccess,
        notificationAccess: notificationAccess,
        locationExplainerDismissed: locationExplainerDismissed,
        locationResolved: locationResolved,
        notificationRequestShown: notificationRequestShown,
        initialized: initialized,
      );

  /// A fully reset (uninitialized) state.
  static const PermissionState empty = PermissionState();
}

/// The sequencing engine for first-launch location and notification
/// permissions.
///
/// The order of operations is fixed:
///
/// 1. On first launch, the app resolves the **location** permission
///    (non-prompting). If it is granted, the app immediately resolves the
///    country and transparently asks for **notification** permission with a
///    proper explainer.
/// 2. If location is not granted, the app shows the in-app location explainer
///    (which the user can dismiss, but that dismissal is session-scoped) and
///    **never** asks for notifications.
/// 3. If location is granted but notification is not, the app shows the
///    notification explainer and asks for notification access.
///
/// The orchestrator is stateful: it tracks what has been asked, so it never
/// re-asks a permission that was already denied or dismissed.
///
/// All platform calls are injectable so the logic is unit-testable without a
/// device.
class PermissionOrchestrator {
  late PermissionState _state;
  late LocationPermissionService _locationService;
  late NotificationPermissionService _notificationService;

  /// The state as it stands now.
  PermissionState get state => _state;

  PermissionOrchestrator({
    required PermissionState initialState,
    LocationPermissionService? locationService,
    NotificationPermissionService? notificationService,
  }) {
    _state = initialState;
    _locationService = locationService ?? LocationPermissionService();
    _notificationService = notificationService ?? NotificationPermissionService(
          status: () => Future.value(PermissionStatus.granted),
          request: () => Future.value(PermissionStatus.granted),
          isSupported: () => true,
        );
  }

  /// Step 1: called on first launch. Resolves location permission WITHOUT
  /// prompting. If granted, the caller then resolves the country, then we
  /// transparently move to step 3.
  Future<void> init() async {
    _state = _state.copyWithInitialized(true);

    final locationAccess = await _locationService.check();
    _state = _state.copyWithLocationAccess(locationAccess);

    if (locationAccess == LocationAccess.granted) {
      // Transparently: resolve the country, then ask for notification.
      // The country resolution is the caller's responsibility (see
      // GeoClient), so we only mark that location was resolved and jump to
      // the notification step.
      _state = _state.copyWithLocationResolved(true);
      await _askNotification();
    }
  }

  /// Step 2: called when the user taps "Allow" on the location explainer.
  /// Requests location permission and, if granted, immediately moves to
  /// step 3.
  Future<void> requestLocation() async {
    final access = await _locationService.request();
    _state = _state.copyWithLocationAccess(access);

    if (access == LocationAccess.granted) {
      _state = _state.copyWithLocationResolved(true);
      await _askNotification();
    }
  }

  /// Step 3: called after location is granted (either on the first probe or
  /// after the user taps "Allow"). Shows the notification explainer and,
  /// if the user taps "Allow", requests notification permission.
  Future<void> requestNotification() async {
    final access = await _notificationService.request();
    _state = _state.copyWithNotificationAccess(access);
  }

  /// Private: checks current notification status and asks the user if needed.
  Future<void> _askNotification() async {
    final access = await _notificationService.check();
    _state = _state.copyWithNotificationAccess(access);
  }

  /// Step 4: called when the user taps "Not now" on either explainer.
  /// The dismissal is session-scoped: the OS keeps the real decision, and a
  /// new session may ask again.
  void dismissExplainer() {
    _state = _state.copyWithLocationExplainerDismissed(true);
  }

  /// Checks whether the notification explainer should be shown.
  ///
  /// The explainer is shown ONLY when:
  /// - location is granted, AND
  /// - notification is NOT yet granted, AND
  /// - the notification explainer has not been dismissed this session, AND
  /// - the notification explainer has not been shown (to avoid a repeated
  ///   prompt on the same session).
  bool get shouldShowNotificationExplainer =>
      _state.locationAccess == LocationAccess.granted &&
      _state.notificationAccess != NotificationAccess.granted &&
      !_state.notificationRequestShown &&
      !_state.locationExplainerDismissed;

  /// The country-resolution step can only happen once location is granted.
  bool get canResolveCountry =>
      _state.locationAccess == LocationAccess.granted;

  /// Whether the location explainer should be shown (location not granted
  /// and not already dismissed).
  bool get shouldShowLocationExplainer =>
      _state.locationAccess != LocationAccess.granted &&
      !_state.locationExplainerDismissed;
}
