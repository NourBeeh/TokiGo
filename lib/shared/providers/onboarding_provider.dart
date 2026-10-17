import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Whether the first-launch onboarding has already been seen.
///
/// Backed by a lightweight Hive settings box so the intro shows exactly once
/// across launches.
class OnboardingState {
  const OnboardingState({this.seen = false, this.ready = false});

  final bool seen;
  final bool ready;
}

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController() : super(const OnboardingState()) {
    _load();
  }

  static const String _boxName = 'tokigo_settings';
  static const String _seenKey = 'onboarding_seen';
  Box<Map>? _box;

  Future<void> _load() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox<Map>(_boxName);
      } else {
        _box = Hive.box<Map>(_boxName);
      }
      final seen = (_box!.get(_seenKey)?['value'] as bool?) ?? false;
      state = OnboardingState(seen: seen, ready: true);
    } catch (_) {
      // Storage unavailable (e.g. Hive not yet initialized — tests, very
      // early launches). Never block the app on the intro flag; fall back
      // to unseen so onboarding still shows once.
      state = const OnboardingState(seen: false, ready: true);
    }
  }

  Future<void> markSeen() async {
    state = const OnboardingState(seen: true, ready: true);
    try {
      await _box?.put(_seenKey, <String, dynamic>{'value': true});
    } catch (_) {}
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>(
  (ref) => OnboardingController(),
);
