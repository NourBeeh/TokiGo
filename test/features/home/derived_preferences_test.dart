import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/memory/derived_preference_profile.dart';
import 'package:tokigo/core/profile/profile_repository.dart';
import 'package:tokigo/features/home/application/recommendation_service.dart';
import 'package:tokigo/features/home/domain/home_composer.dart';
import 'package:tokigo/features/home/domain/personalization_context.dart';

/// Phase 2B — Behavioral Memory + Derived Preference Profile (Flutter side).
///
/// Covers the §22 Flutter list: derived profile serialization, context
/// serialization including derivedPreferences, safeAiContext exclusions,
/// ranking receiving derived preferences, guest behaviour unchanged,
/// personalization-disabled safety, tolerant ProfileView parsing, and
/// repository/API failure fallback (null derived → 1C ranking intact).

PersonalizationCandidate candidate(String id, String title,
        {double? price, double? rating}) =>
    PersonalizationCandidate(id: id, title: title, price: price, rating: rating);

PersonalizationContext contextWith({
  HomeUserState userState = HomeUserState.authenticated,
  bool personalizationEnabled = true,
  DerivedPreferenceProfile? derived,
  List<RecentSearchSignal> recentSearches = const [],
  ProfileView? profile,
}) {
  return PersonalizationContext(
    userState: userState,
    personalizationEnabled: personalizationEnabled,
    derivedPreferences: derived,
    recentSearches: recentSearches,
    profile: profile,
  );
}

void main() {
  group('DerivedPreferenceProfile serialization', () {
    test('round-trips every field', () {
      const profile = DerivedPreferenceProfile(
        topDestinations: [
          DerivedDestination(name: 'Dubai', confidence: 0.75, source: 'trip_planned'),
          DerivedDestination(name: 'Cairo', confidence: 0.3, source: 'behavior_event'),
        ],
        budgetRange: DerivedBudgetRange(min: 100, max: 500),
        favoriteHotels: [DerivedHotelRef(hotelId: 'h-1', title: 'Grand')],
        recentDestinations: ['Dubai', 'Cairo'],
      );
      final map = profile.toMap();
      final restored = DerivedPreferenceProfile.fromMap(map);

      expect(restored.topDestinations.length, 2);
      expect(restored.topDestinations.first.name, 'Dubai');
      expect(restored.topDestinations.first.confidence, 0.75);
      expect(restored.topDestinations.first.source, 'trip_planned');
      expect(restored.budgetRange?.min, 100);
      expect(restored.budgetRange?.max, 500);
      expect(restored.favoriteHotels.single.hotelId, 'h-1');
      expect(restored.recentDestinations, ['Dubai', 'Cairo']);
    });

    test('tolerates null / malformed maps without throwing', () {
      expect(DerivedPreferenceProfile.fromMap(null).topDestinations, isEmpty);
      final empty = DerivedPreferenceProfile.fromMap(<String, dynamic>{});
      expect(empty.topDestinations, isEmpty);
      expect(empty.budgetRange, isNull);
      expect(empty.favoriteHotels, isEmpty);
      expect(empty.recentDestinations, isEmpty);

      final malformed = DerivedPreferenceProfile.fromMap(<String, dynamic>{
        'topDestinations': 'not-a-list',
        'budgetRange': 42,
        'favoriteHotels': <dynamic>[{'hotelId': 'ok'}],
      });
      expect(malformed.topDestinations, isEmpty);
      expect(malformed.budgetRange, isNull);
      expect(malformed.favoriteHotels.single.hotelId, 'ok');
    });
  });

  group('ProfileView parses the additive derivedPreferences field', () {
    test('present field parses; absent field stays null (1C behavior)', () {
      final withDerived = ProfileView.fromMap(<String, dynamic>{
        'userId': 'u1',
        'preferences': {},
        'derived': {},
        'personalizationEnabled': true,
        'derivedPreferences': <String, dynamic>{
          'topDestinations': <dynamic>[
            {'name': 'Dubai', 'confidence': 0.9, 'source': 'behavior_event'}
          ],
          'recentDestinations': <dynamic>['Dubai'],
        },
      });
      expect(withDerived.derivedPreferences?.topDestinations.single.name, 'Dubai');
      expect(withDerived.derivedPreferences?.recentDestinations, ['Dubai']);

      // Older/legacy response shape: the field simply doesn't exist.
      final legacy = ProfileView.fromMap(<String, dynamic>{
        'userId': 'u1',
        'preferences': {},
        'derived': {},
      });
      expect(legacy.derivedPreferences, isNull);
      // ...and everything else still parses (regression guard).
      expect(legacy.userId, 'u1');
      expect(legacy.personalizationEnabled, isTrue);
    });
  });

  group('PersonalizationContext — derivedPreferences plumbing', () {
    test('toDebugMap includes the derived signal count (serializable)', () {
      final ctx = contextWith(
        derived: const DerivedPreferenceProfile(
          topDestinations: [DerivedDestination(name: 'Dubai', confidence: 0.9, source: 'behavior_event')],
        ),
      );
      final debug = ctx.toDebugMap();
      expect(debug['derivedTopDestinationCount'], 1);
      // Safe to log: no memory values, no payloads, no provenance dumps.
      expect(debug.toString(), isNot(contains('password')));
    });

    test('safeAiContext exposes ONLY labels/budget bounds — never raw values',
        () {
      final ctx = contextWith(
        derived: const DerivedPreferenceProfile(
          topDestinations: [
            DerivedDestination(name: 'Dubai', confidence: 0.9, source: 'behavior_event'),
          ],
          budgetRange: DerivedBudgetRange(min: 120, max: 900),
          favoriteHotels: [DerivedHotelRef(hotelId: 'h-1', title: 'Grand')],
          recentDestinations: ['Dubai'],
        ),
      );
      final safe = ctx.safeAiContext();
      expect(safe['derivedTopDestinations'], ['Dubai']);
      expect(safe['derivedBudgetMax'], 900);
      // Whitelist guard: no forbidden keys ever.
      expect(
        safe.keys.toSet().intersection(
            {'email', 'password', 'token', 'payment', 'latitude', 'longitude'}),
        isEmpty,
      );
      // No raw memory payload internals in the AI context.
      expect(safe.toString(), isNot(contains('hotelId')));
      expect(safe.toString(), isNot(contains('source')));
    });

    test('personalization disabled keeps safeAiContext minimal', () {
      final ctx = contextWith(
        personalizationEnabled: false,
        derived: const DerivedPreferenceProfile(
          topDestinations: [DerivedDestination(name: 'Dubai', confidence: 0.9, source: 'behavior_event')],
        ),
      );
      expect(ctx.safeAiContext().keys, ['userState']);
    });
  });

  group('RecommendationService receives derived preferences', () {
    const service = RecommendationService();

    test('derived top destination outranks a plain discovery candidate',
        () {
      final ctx = contextWith(
        derived: const DerivedPreferenceProfile(
          topDestinations: [
            DerivedDestination(name: 'Cairo', confidence: 0.9, source: 'behavior_event'),
          ],
        ),
      );
      final ranked = service.rank(
        [candidate('a', 'Paris Luxury Stay'), candidate('b', 'Cairo Grand Hotel')],
        ctx,
      );
      expect(ranked.first.id, 'b');
      expect(ranked.first.reason, 'profile_preference');
      expect(ranked.first.source, 'memory');
    });

    test('derived preferences sit between recent search and explicit stars',
        () {
      // Same-strength competition: a recent-search Cairo candidate vs a
      // derived-Cairo candidate — the derived layer (+5.5) must beat the
      // single recent search (+5).
      final ctx = contextWith(
        recentSearches: [
          RecentSearchSignal(
              kind: 'hotel', label: 'Hotels in Paris', at: DateTime(2026, 9, 1)),
        ],
        derived: const DerivedPreferenceProfile(
          topDestinations: [
            DerivedDestination(name: 'Cairo', confidence: 0.9, source: 'behavior_event'),
          ],
        ),
      );
      final ranked = service.rank(
        [
          candidate('paris', 'Paris Luxury Stay'),
          candidate('cairo', 'Cairo Grand Hotel'),
        ],
        ctx,
      );
      expect(ranked.first.id, 'cairo'); // derived (5.5) > search (5).
      expect(ranked.first.source, 'memory');
    });

    test('explicit stars still outrank derived destinations (§14 ladder)',
        () {
      final ctx = contextWith(
        derived: const DerivedPreferenceProfile(
          topDestinations: [
            DerivedDestination(name: 'Cairo', confidence: 0.9, source: 'behavior_event'),
          ],
        ),
        profile: const ProfileView(
          userId: 'u1',
          preferences: {'preferredStars': 5},
        ),
      );
      final ranked = service.rank(
        [
          candidate('cairo-low', 'Cairo Budget Inn', rating: 2.0),
          candidate('five-star', 'Paris Five Star Palace', rating: 5.0),
        ],
        ctx,
      );
      expect(ranked.first.id, 'five-star'); // explicit wins.
    });

    test('guest context (null derived) keeps Phase 1C ranking EXACTLY', () {
      // No derived preferences at all: identical to the 1C test that
      // already exists — recent search drives the order.
      final guestCtx = contextWith(
        userState: HomeUserState.returningAnonymous,
        recentSearches: [
          RecentSearchSignal(
              kind: 'hotel', label: 'Hotels in Cairo', at: DateTime(2026, 9, 1)),
        ],
      );
      final ranked = service.rank(
        [candidate('a', 'Paris Luxury Stay'), candidate('b', 'Cairo Grand Hotel')],
        guestCtx,
      );
      expect(ranked.first.id, 'b');
      expect(ranked.first.reason, 'recent_search'); // unchanged from 1C.
      expect(ranked.first.source, 'local');
    });

    test('personalization disabled → neutral discovery order (derived ignored)',
        () {
      final ctx = contextWith(
        personalizationEnabled: false,
        derived: const DerivedPreferenceProfile(
          topDestinations: [
            DerivedDestination(name: 'Cairo', confidence: 0.9, source: 'behavior_event'),
          ],
        ),
      );
      final ranked = service.rank(
        [candidate('a', 'Paris Luxury Stay'), candidate('b', 'Cairo Grand Hotel')],
        ctx,
      );
      expect(ranked.map((c) => c.id), ['a', 'b']); // Input order preserved.
      expect(ranked.every((c) => c.reason == 'discovery'), isTrue);
    });

    test('derived budget assists ONLY when explicit budgetMax is absent',
        () {
      final withDerivedBudget = contextWith(
        derived: const DerivedPreferenceProfile(
          budgetRange: DerivedBudgetRange(max: 300),
        ),
      );
      final ranked = service.rank(
        [candidate('cheap', 'Cairo Inn', price: 100), candidate('dear', 'Cairo Palace', price: 500)],
        withDerivedBudget,
      );
      // The under-budget candidate gets the +1.2 derived-budget assist.
      expect(ranked.first.id, 'cheap');

      // With an explicit budgetMax the derived one is ignored entirely.
      final explicitCtx = contextWith(
        profile: const ProfileView(
          userId: 'u1',
          preferences: {'budgetMax': 300},
        ),
        derived: const DerivedPreferenceProfile(
          budgetRange: DerivedBudgetRange(max: 50),
        ),
      );
      final rankedExplicit = service.rank(
        [candidate('mid', 'Cairo Inn', price: 100), candidate('low', 'Cairo Hostel', price: 40)],
        explicitCtx,
      );
      // Explicit 300: BOTH fit; the derived 50 must NOT have applied —
      // otherwise 'low' (40 ≤ 50) would have scored higher than 'mid'.
      expect(rankedExplicit.first.id, 'mid');
    });

    test('repository/API failure path: null profile keeps ranking intact',
        () {
      // The orchestrator's profile branch returns null on any failure —
      // the context then carries no derivedPreferences and ranking falls
      // back to the pure 1C behaviour (never an error state).
      final ctx = PersonalizationContext(
        userState: HomeUserState.authenticated,
        profile: null,
        derivedPreferences: null,
      );
      final ranked = service.rank(
        [candidate('a', 'A Hotel'), candidate('b', 'B Hotel')],
        ctx,
      );
      expect(ranked, hasLength(2));
      expect(ranked.every((c) => c.source == 'recommendation'), isTrue);
    });
  });
}
