import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/storage/offline_cache_providers.dart';

/// Persisted state for the contextual location prompt.
///
/// The prompt is deliberately quiet: it may be shown at most
/// [LocationPromptController.maxImpressions] times, a dismissal silences it
/// for [LocationPromptController.cooldown], and it never blocks a flow.
@immutable
class LocationPromptState {
  const LocationPromptState({
    this.impressions = 0,
    this.dismissedAt,
  });

  final int impressions;
  final DateTime? dismissedAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'impressions': impressions,
    'dismissedAt': dismissedAt?.toUtc().toIso8601String(),
  };

  static LocationPromptState fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return const LocationPromptState();
    final int impressions = raw['impressions'] is num
        ? (raw['impressions'] as num).toInt().clamp(0, 1 << 20)
        : 0;
    final DateTime? dismissedAt = DateTime.tryParse(
      raw['dismissedAt']?.toString() ?? '',
    );
    return LocationPromptState(
      impressions: impressions,
      dismissedAt: dismissedAt,
    );
  }
}

/// Owns the prompt's impression count and dismissal window.
class LocationPromptController extends Notifier<LocationPromptState> {
  static const String cacheKey = 'settings:location-prompt';
  static const int maxImpressions = 2;
  static const Duration cooldown = Duration(days: 14);

  int _generation = 0;

  @override
  LocationPromptState build() {
    _restore();
    return const LocationPromptState();
  }

  Future<void> _restore() async {
    final int generation = _generation;
    try {
      final Map<String, dynamic>? stored =
          await ref.read(offlineCacheProvider).read(cacheKey);
      if (generation != _generation) return;
      state = LocationPromptState.fromMap(stored);
    } catch (_) {
      // An unavailable cache simply means the prompt starts fresh.
    }
  }

  /// Whether the prompt may be shown now. Callers still gate on permission
  /// state and on whether a manual city already exists.
  bool mayShow({DateTime? now}) {
    if (state.impressions >= maxImpressions) return false;
    final DateTime? dismissed = state.dismissedAt;
    if (dismissed == null) return true;
    final DateTime clock = (now ?? DateTime.now()).toUtc();
    return clock.difference(dismissed.toUtc()) >= cooldown;
  }

  /// Records one display. Called once per mounting of the card.
  Future<void> recordImpression() async {
    if (state.impressions >= maxImpressions) return;
    _generation += 1;
    state = LocationPromptState(
      impressions: state.impressions + 1,
      dismissedAt: state.dismissedAt,
    );
    await _persist();
  }

  /// "Not now": silence the prompt for [cooldown].
  Future<void> dismiss({DateTime? now}) async {
    _generation += 1;
    state = LocationPromptState(
      impressions: state.impressions,
      dismissedAt: (now ?? DateTime.now()).toUtc(),
    );
    await _persist();
  }

  /// Clears the counters. Used by tests and by an explicit reset path; there
  /// is no customer-facing control that calls it.
  Future<void> reset() async {
    _generation += 1;
    state = const LocationPromptState();
    try {
      await ref.read(offlineCacheProvider).delete(cacheKey);
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      await ref
          .read(offlineCacheProvider)
          .write(cacheKey, state.toMap());
    } catch (_) {
      // Best-effort: the in-memory state still governs this session.
    }
  }
}

final locationPromptControllerProvider =
    NotifierProvider<LocationPromptController, LocationPromptState>(
      LocationPromptController.new,
    );
