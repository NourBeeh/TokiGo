import 'package:tokigo/core/memory/derived_preference_profile.dart';
import 'package:tokigo/core/memory/explicit_preference_signal.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';

/// Read-only user profile for personalization (Phase 1C).
///
/// Mirrors the R-4 backend `GET /profile/me` view exactly — no parallel model
/// beyond the wire contract. `derived` carries engine-folded behavioral
/// signals (topDestinations, budget, favoriteHotels, ...); `preferences` are
/// the explicit user preferences. Both stay opaque maps here: consumers pick
/// the keys they trust.
class ProfileView {
  const ProfileView({
    required this.userId,
    this.preferences = const {},
    this.derived = const {},
    this.countryCode,
    this.countryConfidence,
    this.personalizationEnabled = true,
    this.derivedPreferences,
    this.explicitPreferences,
  });

  factory ProfileView.fromMap(Map<String, dynamic> map) {
    return ProfileView(
      userId: map['userId']?.toString() ?? '',
      preferences: map['preferences'] is Map
          ? Map<String, dynamic>.from(map['preferences'])
          : const {},
      derived: map['derived'] is Map
          ? Map<String, dynamic>.from(map['derived'])
          : const {},
      countryCode: map['countryCode']?.toString(),
      countryConfidence: map['countryConfidence']?.toString(),
      personalizationEnabled: map['personalizationEnabled'] != false,
      // Phase 2B — additive field; older responses (or upstream failures)
      // leave it null and every consumer behaves exactly as Phase 1C.
      derivedPreferences: map['derivedPreferences'] is Map
          ? DerivedPreferenceProfile.fromMap(
              Map<String, dynamic>.from(map['derivedPreferences'] as Map),
            )
          : null,
      // PH-7 — additive field: explicit AI-conversation preferences. Older
      // responses (or opt-out) leave it null and every consumer behaves
      // exactly as before.
      explicitPreferences: map['explicitPreferences'] is Map
          ? ExplicitPreferenceSignal.fromMap(
              Map<String, dynamic>.from(map['explicitPreferences'] as Map),
            )
          : null,
    );
  }

  final String userId;
  final Map<String, dynamic> preferences;
  final Map<String, dynamic> derived;
  final String? countryCode;
  final String? countryConfidence;

  /// Opt-out switch: when false the caller must NOT use sensitive
  /// personalization signals and falls back to the discovery-safe
  /// composition.
  final bool personalizationEnabled;

  /// Phase 2B — computed behavioral read model from the memory spine
  /// (topDestinations/budgetRange/favoriteHotels/recentDestinations). Null
  /// for guests, older backends, or derivation failures.
  final DerivedPreferenceProfile? derivedPreferences;

  /// PH-7 — explicit AI-conversation preference signal (separate from the
  /// behavioural derived read model). Null for guests/opt-out/no facts.
  final ExplicitPreferenceSignal? explicitPreferences;

  /// Derived favorite hotel titles (capped list maintained by the backend).
  List<String> get favoriteHotelTitles {
    final raw = derived['favoriteHotels'];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).take(20).toList();
  }

  /// Derived last-viewed hotel title, when present.
  String? get lastViewedHotelTitle {
    final raw = derived['lastViewedHotel'];
    return raw is Map ? raw['title']?.toString() : raw?.toString();
  }

  /// Derived upcoming destination (from trip_planned/booking_confirmed).
  String? get upcomingDestination => derived['upcomingDestination']?.toString();

  /// Derived top destinations (from hotel_search folding).
  List<String> get topDestinations {
    final raw = derived['topDestinations'];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).take(6).toList();
  }
}

/// Fetches the authenticated user's profile. Never throws — a missing token
/// or any failure yields null so Home can continue with local data.
class ProfileRepository {
  ProfileRepository(this._client, this._tokenStorage);

  final ApiClient _client;
  final SecureTokenStorage _tokenStorage;

  Future<ProfileView?> fetchProfile() async {
    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) return null;
      final result = await _client.get<Map<String, dynamic>>(
        '/profile/me',
        headers: <String, String>{'Authorization': 'Bearer $token'},
      );
      // Explicit R: `when` is synchronous — without it the return context
      // infers FutureOr and trips `unawaited_return_in_try_block`.
      return result.when<ProfileView?>(
        success: (data) => ProfileView.fromMap(data),
        failure: (_) => null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Persist the resolved country only. Precise device coordinates are never
  /// written to the user profile.
  Future<void> saveDetectedCountry(
    String countryCode,
    String confidence,
  ) async {
    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) return;
      await _client.patch<Map<String, dynamic>>(
        '/profile/me',
        headers: <String, String>{'Authorization': 'Bearer $token'},
        body: <String, String>{
          'countryCode': countryCode,
          'countryConfidence': confidence,
        },
      );
    } catch (_) {
      // Location is optional; country lookup and the Home feed keep working.
    }
  }
}
