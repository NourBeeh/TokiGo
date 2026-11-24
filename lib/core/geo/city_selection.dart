import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/geo/city_catalog.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';

/// How the effective city was established. Internal only — never surfaced as
/// a customer-facing control.
enum CitySelectionSource { manual, gps, ip, cached }

/// A persisted city choice.
@immutable
class SelectedCity {
  const SelectedCity({
    required this.city,
    required this.source,
    required this.updatedAt,
  });

  final CityOption city;
  final CitySelectionSource source;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'city': city.toMap(),
    'source': source.name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static SelectedCity? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(
      raw.map((Object? key, Object? value) => MapEntry(key.toString(), value)),
    );
    final CityOption? city = CityOption.tryParse(map['city']);
    if (city == null) return null;
    final String sourceName = map['source']?.toString() ?? 'cached';
    final CitySelectionSource source = CitySelectionSource.values.firstWhere(
      (CitySelectionSource value) => value.name == sourceName,
      orElse: () => CitySelectionSource.cached,
    );
    final DateTime updatedAt =
        DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
        DateTime.now().toUtc();
    return SelectedCity(city: city, source: source, updatedAt: updatedAt);
  }
}

enum CitySelectionStatus { loading, ready, unavailable }

const Object _unset = Object();

/// Manual selection is the customer's explicit preference. Automatic
/// detection may update [automatic] but must NEVER replace [manual].
@immutable
class CitySelectionState {
  const CitySelectionState({
    this.manual,
    this.automatic,
    this.status = CitySelectionStatus.loading,
  });

  final SelectedCity? manual;
  final SelectedCity? automatic;
  final CitySelectionStatus status;

  /// The city the rest of the app should use.
  SelectedCity? get effective => manual ?? automatic;

  bool get isManual => manual != null;

  CitySelectionState copyWith({
    Object? manual = _unset,
    Object? automatic = _unset,
    CitySelectionStatus? status,
  }) {
    return CitySelectionState(
      manual: identical(manual, _unset) ? this.manual : manual as SelectedCity?,
      automatic: identical(automatic, _unset)
          ? this.automatic
          : automatic as SelectedCity?,
      status: status ?? this.status,
    );
  }
}

/// Owns the persisted city selection.
///
/// Storage keys are deliberately separate so a background detection write can
/// never clobber a manual choice, even if two writes race.
class CitySelectionController extends Notifier<CitySelectionState> {
  static const String manualKey = 'settings:city-manual';
  static const String automaticKey = 'settings:city-automatic';

  int _generation = 0;

  @override
  CitySelectionState build() {
    _restore();
    return const CitySelectionState();
  }

  Future<void> _restore() async {
    final int generation = _generation;
    SelectedCity? manual;
    SelectedCity? automatic;
    try {
      final cache = ref.read(offlineCacheProvider);
      final manualStored = await cache.read(manualKey);
      final automaticStored = await cache.read(automaticKey);
      if (generation != _generation) return;
      manual = SelectedCity.tryParse(manualStored?['selection']);
      automatic = SelectedCity.tryParse(automaticStored?['selection']);
    } catch (_) {
      // An unavailable cache leaves the selection empty; the customer can pick
      // a city again. Detection retries on the next launch.
    }
    if (generation != _generation) return;
    state = CitySelectionState(
      manual: manual,
      automatic: automatic,
      status: manual == null && automatic == null
          ? CitySelectionStatus.unavailable
          : CitySelectionStatus.ready,
    );
  }

  /// Applies an explicit customer choice. This always wins over detection.
  Future<void> selectManual(CityOption city) async {
    _generation += 1;
    final SelectedCity selection = SelectedCity(
      city: city,
      source: CitySelectionSource.manual,
      updatedAt: DateTime.now().toUtc(),
    );
    state = state.copyWith(
      manual: selection,
      status: CitySelectionStatus.ready,
    );
    try {
      await ref.read(offlineCacheProvider).write(manualKey, <String, dynamic>{
        'selection': selection.toMap(),
      });
    } catch (_) {
      // The in-memory choice stands; persistence can be retried on the next
      // explicit selection.
    }
  }

  /// Applies a background-detected city. A no-op while a manual choice exists.
  Future<void> setAutomatic(
    CityOption city, {
    required CitySelectionSource source,
  }) async {
    if (state.manual != null) return;
    if (source == CitySelectionSource.manual) {
      throw ArgumentError('setAutomatic cannot write a manual selection');
    }
    final SelectedCity selection = SelectedCity(
      city: city,
      source: source,
      updatedAt: DateTime.now().toUtc(),
    );
    state = state.copyWith(
      automatic: selection,
      status: CitySelectionStatus.ready,
    );
    try {
      await ref.read(offlineCacheProvider).write(automaticKey, <String, dynamic>{
        'selection': selection.toMap(),
      });
    } catch (_) {
      // Best-effort persistence; the session value still applies.
    }
  }

  /// Clears the manual choice (internal/test use — there is deliberately no
  /// customer-facing "return to automatic" control).
  Future<void> clearManual() async {
    _generation += 1;
    state = state.copyWith(
      manual: null,
      status: state.automatic == null
          ? CitySelectionStatus.unavailable
          : CitySelectionStatus.ready,
    );
    try {
      await ref.read(offlineCacheProvider).delete(manualKey);
    } catch (_) {}
  }
}

final citySelectionProvider =
    NotifierProvider<CitySelectionController, CitySelectionState>(
      CitySelectionController.new,
    );

/// The city every surface should use, or null while nothing is resolved.
final effectiveCityProvider = Provider<CityOption?>((ref) {
  return ref.watch(citySelectionProvider).effective?.city;
});

/// The effective city's ISO-4217 currency, used as the default display
/// currency when the traveller has not made an explicit choice.
final effectiveCityCurrencyProvider = Provider<String?>((ref) {
  return ref.watch(citySelectionProvider).effective?.city.currency;
});

/// Whether a manual city is active (drives the location prompt's visibility).
final hasManualCityProvider = Provider<bool>((ref) {
  return ref.watch(citySelectionProvider).isManual;
});
