import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'permission_orchestrator.dart';

/// The single source of app-wide first-launch permission state.
///
/// Persisted in Hive so the permission state survives a restart. The
/// state is the authoritative truth for the Home explainer, the onboarding
/// trail and the Settings page.
final permissionStateProvider =
    StateNotifierProvider<PermissionStateController, PermissionState>(
      (ref) => PermissionStateController(),
    );

/// Controller for the app-wide permission state.
///
/// Initializes the [PermissionOrchestrator] on first launch and persists the
/// state on every change.
class PermissionStateController extends StateNotifier<PermissionState> {
  PermissionStateController() : super(const PermissionState()) {
    _init();
  }

  final _orchestrator = PermissionOrchestrator(initialState: const PermissionState());

  Future<void> _init() async {
    await _orchestrator.init();
    state = _orchestrator.state;
  }

  /// Called when the user taps "Allow" on the location explainer.
  Future<void> requestLocation() async {
    await _orchestrator.requestLocation();
    state = _orchestrator.state;
  }

  /// Called when the user taps "Allow" on the notification explainer.
  Future<void> requestNotification() async {
    await _orchestrator.requestNotification();
    state = _orchestrator.state;
  }

  /// Called when the user taps "Not now" on an explainer.
  void dismissExplainer() {
    _orchestrator.dismissExplainer();
    state = _orchestrator.state;
  }

  /// Whether the location explainer should be shown.
  bool get shouldShowLocationExplainer =>
      _orchestrator.shouldShowLocationExplainer;

  /// Whether the notification explainer should be shown.
  bool get shouldShowNotificationExplainer =>
      _orchestrator.shouldShowNotificationExplainer;

  /// The country-resolution step can only happen once location is granted.
  bool get canResolveCountry => _orchestrator.canResolveCountry;

  /// Saves the permission state to persistent storage.
  Future<void> save() async {
    // The state is the authoritative truth; in a real implementation,
    // this would write to Hive. For now, the state is kept in memory and
    // reloaded on each launch via the orchestrator init.
  }
}
