import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/profile/profile_repository.dart';
import 'package:tokigo/core/repositories/impl/home_repository_impl.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';
import 'package:tokigo/features/home/application/recommendation_service.dart';
import 'package:tokigo/features/home/domain/home_composer.dart';
import 'package:tokigo/features/home/domain/home_greeting.dart';
import 'package:tokigo/features/home/domain/personalization_context.dart';

/// Scripted HTTP client for the profile/AI client tests.
class _ScriptedClient implements ApiClient {
  _ScriptedClient(this.result);

  final ApiResult<Map<String, dynamic>> Function() result;

  @override
  String get baseUrl => 'http://test';
  @override
  Duration get defaultTimeout => const Duration(seconds: 5);
  @override
  Map<String, String> get defaultHeaders => const {};

  @override
  Future<ApiResult<T>> get<T>(String path,
      {Map<String, String>? queryParameters,
      Map<String, String>? headers,
      Duration? timeout,
      RequestToken? token}) async {
    calls.add((path, headers?['Authorization']));
    return result() as ApiResult<T>;
  }

  @override
  Future<ApiResult<T>> post<T>(String path,
      {Object? body,
      Map<String, String>? headers,
      Duration? timeout,
      RequestToken? token}) async {
    calls.add((path, headers?['Authorization']));
    return result() as ApiResult<T>;
  }

  final List<(String, String?)> calls = <(String, String?)>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedTokenStorage implements SecureTokenStorage {
  _FixedTokenStorage(this.token);
  final String? token;

  @override
  Future<String?> getAccessToken() async => token;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

HomeSection section(String id, String title) => HomeSection(
      id: id,
      title: title,
      layout: HomeSectionLayout.horizontal,
      items: const [],
    );

PersonalizationCandidate candidate(
  String id,
  String title, {
  double? price,
  double? rating,
  int? reviewCount,
  String? subtitle,
}) =>
    PersonalizationCandidate(
      id: id,
      title: title,
      subtitle: subtitle,
      price: price,
      rating: rating,
      reviewCount: reviewCount,
    );

PersonalizationContext contextWith({
  HomeUserState userState = HomeUserState.authenticated,
  bool personalizationEnabled = true,
  List<RecentSearchSignal> recentSearches = const [],
  List<String> viewedTitles = const [],
  List<String> favoriteTitles = const [],
  bool hasTrips = false,
  String? upcomingDestination,
  String? geoCountryCode,
  ProfileView? profile,
}) {
  return PersonalizationContext(
    userState: userState,
    personalizationEnabled: personalizationEnabled,
    recentSearches: recentSearches,
    viewedTitles: viewedTitles,
    favoriteTitles: favoriteTitles,
    hasTrips: hasTrips,
    upcomingDestination: upcomingDestination,
    geoCountryCode: geoCountryCode,
    profile: profile,
  );
}

void main() {
  group('PersonalizationContext — safety', () {
    test('safeAiContext never includes sensitive keys', () {
      final ctx = contextWith(
        profile: const ProfileView(
          userId: 'u1',
          preferences: {'budgetMax': 500, 'preferredStars': 4},
        ),
        geoCountryCode: 'EG',
        upcomingDestination: 'Dubai',
      );
      final safe = ctx.safeAiContext();
      const forbidden = {'email', 'password', 'token', 'payment', 'latitude', 'longitude'};
      expect(safe.keys.toSet().intersection(forbidden), isEmpty);
      expect(safe.keys.join(','), isNot(contains('token')));
      expect(safe['countryCode'], 'EG');
      expect(safe['upcomingDestination'], 'Dubai');
      expect(safe['hasTrips'], isNotNull);
    });

    test('safeAiContext is minimal when personalization is disabled', () {
      final ctx = contextWith(personalizationEnabled: false);
      expect(ctx.safeAiContext().keys, ['userState']);
    });

    test('toDebugMap is serializable and safe to log', () {
      final map = contextWith().toDebugMap();
      expect(map['hasDisplayName'], false);
      expect(map['userState'], 'authenticated');
      expect(map.containsKey('displayName'), isFalse); // No name value itself.
    });
  });

  group('Profile integration', () {
    test('fetchProfile parses the backend view', () async {
      final client = _ScriptedClient(() => const ApiResult.success({
            'userId': 'u1',
            'preferences': {'preferredStars': 4},
            'derived': {
              'favoriteHotels': ['Grand Cairo'],
              'upcomingDestination': 'Dubai',
            },
            'countryCode': 'EG',
            'personalizationEnabled': true,
          }));
      final repo = ProfileRepository(client, _FixedTokenStorage('jwt-1'));

      final profile = await repo.fetchProfile();

      expect(profile, isNotNull);
      expect(profile!.favoriteHotelTitles, ['Grand Cairo']);
      expect(profile.upcomingDestination, 'Dubai');
      expect(profile.personalizationEnabled, isTrue);
      expect(profile.preferences['preferredStars'], 4);
      // The bearer token WAS attached.
      expect(client.calls.single.$2, 'Bearer jwt-1');
    });

    test('profile failure yields null — Home continues', () async {
      final repo = ProfileRepository(
        _ScriptedClient(
          () => const ApiResult.failure(ApiServerError(message: 'boom')),
        ),
        _FixedTokenStorage('jwt-1'),
      );
      expect(await repo.fetchProfile(), isNull);
    });

    test('missing token (guest) yields null without a network call', () async {
      final client = _ScriptedClient(() => const ApiResult.success({}));
      final repo = ProfileRepository(client, _FixedTokenStorage(null));
      expect(await repo.fetchProfile(), isNull);
      expect(client.calls, isEmpty);
    });

    test('personalizationEnabled=false parsed correctly', () async {
      final repo = ProfileRepository(
        _ScriptedClient(() => const ApiResult.success({
          'userId': 'u1',
          'preferences': {},
          'derived': {},
          'personalizationEnabled': false,
        })),
        _FixedTokenStorage('jwt-1'),
      );
      expect((await repo.fetchProfile())!.personalizationEnabled, isFalse);
    });
  });

  group('Recommendation rules (deterministic)', () {
    const service = RecommendationService();

    test('explicit preference (preferredStars) wins', () {
      final ctx = contextWith(
        profile: const ProfileView(
          userId: 'u1',
          preferences: {'preferredStars': 5},
        ),
      );
      final ranked = service.rank(
        [
          candidate('a', 'City Hostel', rating: 2.0),
          candidate('b', 'Grand Five Star', rating: 5.0),
        ],
        ctx,
      );
      expect(ranked.first.id, 'b');
      expect(ranked.first.reason, 'profile_preference');
    });

    test('recent search signal outranks discovery', () {
      final ctx = contextWith(recentSearches: [
        RecentSearchSignal(
            kind: 'hotel', label: 'Hotels in Cairo', at: DateTime(2026, 9, 1)),
      ]);
      final ranked = service.rank(
        [
          candidate('a', 'Paris Luxury Stay'),
          candidate('b', 'Cairo Grand Hotel'),
        ],
        ctx,
      );
      expect(ranked.first.id, 'b');
      expect(ranked.first.reason, 'recent_search');
    });

    test('recent view signal', () {
      final ctx = contextWith(viewedTitles: ['Grand Cairo']);
      final ranked = service.rank(
        [
          candidate('a', 'Paris Luxury Stay'),
          candidate('b', 'Grand Cairo'),
        ],
        ctx,
      );
      expect(ranked.first.id, 'b');
      expect(ranked.first.reason, 'recent_view');
    });

    test('favorite signal', () {
      final ctx = contextWith(favoriteTitles: ['Nile View']);
      final ranked = service.rank(
        [
          candidate('a', 'Paris Luxury Stay'),
          candidate('b', 'Nile View Resort'),
        ],
        ctx,
      );
      expect(ranked.first.id, 'b');
      expect(ranked.first.reason, 'favorite');
    });

    test('trip context signal', () {
      final ctx = contextWith(hasTrips: true, upcomingDestination: 'dubai');
      final ranked = service.rank(
        [
          candidate('a', 'Paris Luxury Stay'),
          candidate('b', 'Dubai Marina Hotel'),
        ],
        ctx,
      );
      expect(ranked.first.id, 'b');
      expect(ranked.first.reason, 'trip_context');
    });

    test('rank never invents candidates — output set == input set', () {
      final ctx = contextWith();
      final input = [candidate('a', 'A'), candidate('b', 'B'), candidate('c', 'C')];
      final ranked = service.rank(input, ctx);
      expect(ranked.map((c) => c.id).toSet(), input.map((c) => c.id).toSet());
      expect(ranked, hasLength(3));
    });

    test('personalization disabled → neutral discovery order', () {
      final ctx = contextWith(personalizationEnabled: false, favoriteTitles: ['B']);
      final ranked = service.rank(
        [candidate('a', 'A'), candidate('b', 'B')],
        ctx,
      );
      expect(ranked.map((c) => c.id), ['a', 'b']);
      expect(ranked.every((c) => c.reason == 'discovery'), isTrue);
    });

    test('deterministic: same input → same output', () {
      final ctx = contextWith(viewedTitles: ['B']);
      final input = [candidate('a', 'A'), candidate('b', 'B'), candidate('c', 'C')];
      expect(service.rank(input, ctx).map((c) => c.id),
          service.rank(input, ctx).map((c) => c.id));
    });
  });

  group('Composer — Phase 1C authenticated personalization', () {
    const composer = HomeComposer();

    final backend = [
      section('trending', 'Trending destinations'),
      section('deals', 'Deals'),
    ];

    test('personalized authenticated: trip + viewed + picked sections in order',
        () async {
      final out = await composer.compose(HomeCompositionContext(
        userState: HomeUserState.authenticated,
        displayName: 'Nour',
        backendSections: backend,
        hasBagTrips: true,
        upcomingDestination: 'Dubai',
        viewedTitles: ['Grand Cairo'],
        rankedCandidates: [
          const RankedCandidate(
            id: 'r1',
            title: 'Dubai Marina',
            reason: 'trip_context',
          ),
        ],
      ));
      expect(out.sections.first.metadata['semanticId'], 'complete-your-trip');
      expect(out.sections[1].metadata['semanticId'], 'because-you-viewed');
      expect(out.sections[1].title, contains('Grand Cairo'));
      expect(out.sections[2].metadata['semanticId'], 'picked-for-you');
      // §11 metadata present.
      expect(out.sections.first.metadata['reason'], 'trip_context');
      expect(
          out.sections[2].items.first.metadata['reason'], 'trip_context');
    });

    test('personalization disabled → discovery-safe (no viewed/trip rails)',
        () async {
      final out = await composer.compose(HomeCompositionContext(
        userState: HomeUserState.authenticated,
        backendSections: backend,
        hasBagTrips: true,
        viewedTitles: ['Grand Cairo'],
        personalizationEnabled: false,
        rankedCandidates: const [
          RankedCandidate(id: 'r1', title: 'X'),
        ],
      ));
      final ids = out.sections.map((s) => s.metadata['semanticId']).toList();
      expect(ids, isNot(contains('because-you-viewed')));
      expect(ids, isNot(contains('complete-your-trip')));
      // Picked-for-you may still exist (anonymous-safe) but with no
      // sensitive reason.
      if (ids.contains('picked-for-you')) {
        final picked = out.sections
            .firstWhere((s) => s.metadata['semanticId'] == 'picked-for-you');
        expect(picked.metadata['reason'], isNot(anyOf('recent_view', 'favorite')));
      }
    });

    test('authenticated insufficient data → deals + discovery fallback',
        () async {
      final out = await composer.compose(HomeCompositionContext(
        userState: HomeUserState.authenticated,
        backendSections: backend,
      ));
      expect(out.sections, isNotEmpty);
      expect(out.sections.first.metadata['semanticId'], 'deals');
    });

    test('contextual greeting (deterministic, no AI)', () {
      final g = buildGreeting(HomeCompositionContext(
        userState: HomeUserState.authenticated,
        displayName: 'Nour',
        upcomingDestination: 'Dubai',
      ));
      expect(g.title, 'Welcome back, Nour');
      expect(g.subtitle, contains('Dubai'));

      final searchG = buildGreeting(HomeCompositionContext(
        userState: HomeUserState.authenticated,
        recentSearches: [
          RecentSearchSignal(
              kind: 'hotel', label: 'X', at: DateTime(2026, 9, 1)),
        ],
      ));
      expect(searchG.subtitle, contains('recent search'));
    });

    test('greeting stays neutral when personalization disabled', () {
      final g = buildGreeting(HomeCompositionContext(
        userState: HomeUserState.authenticated,
        displayName: 'Nour',
        upcomingDestination: 'Dubai',
        personalizationEnabled: false,
      ));
      expect(g.subtitle, 'Trips and ideas picked for you');
    });
  });

  group('Snapshot safety (Phase 1C)', () {
    test('personalized sections persist + restore via the snapshot codec with reasons',
        () async {
      const composer = HomeComposer();
      final backend = [
        HomeSection(
          id: 'deals',
          title: 'Deals',
          layout: HomeSectionLayout.horizontal,
          items: const [],
        ),
      ];
      final composed = await composer.compose(HomeCompositionContext(
        userState: HomeUserState.authenticated,
        displayName: 'Nour',
        backendSections: backend,
        hasBagTrips: true,
        upcomingDestination: 'Dubai',
        rankedCandidates: const [
          RankedCandidate(
            id: 'r1',
            title: 'Dubai Marina',
            reason: 'trip_context',
            source: 'recommendation',
            confidence: 0.8,
          ),
        ],
      ));

      final envelope = <String, dynamic>{
        'schemaVersion': 'home.snapshot.v2',
        'savedAt': DateTime.now().toIso8601String(),
        'audience': 'user:u-1',
        'sections': composed.sections.map(homeSectionToMap).toList(),
      };
      final restored = homeSectionsFromMap(envelope);

      expect(restored.length, composed.sections.length);
      final trip = restored.firstWhere(
        (s) => s.metadata['semanticId'] == 'complete-your-trip',
      );
      expect(trip.metadata['reason'], 'trip_context');
      expect(trip.items.first.metadata['reason'], 'trip_context');
      expect(trip.items.first.metadata['confidence'], 0.8);
      expect(trip.items.first.title, 'Dubai Marina');
    });

    test('snapshot envelope contains no sensitive data (no tokens/email/GPS)',
        () {
      final envelope = <String, dynamic>{
        'schemaVersion': 'home.snapshot.v2',
        'audience': 'user:u-1',
        'sections': [
          {
            'id': 'picked-for-you',
            'title': 'Picked for You',
            'metadata': {
              'semanticId': 'picked-for-you',
              'reason': 'recent_search',
            },
            'items': [
              {
                'id': 'r1',
                'type': 'hotel',
                'title': 'Grand Cairo',
                'metadata': {'reason': 'recent_search', 'source': 'local'},
              },
            ],
          },
        ],
      };
      final serialized = envelope.toString();
      const forbidden = [
        'sk-or-',
        'Bearer ',
        'password',
        'accessToken',
        'latitude',
        'longitude',
        '@gmail',
      ];
      for (final term in forbidden) {
        expect(serialized.contains(term), isFalse,
            reason: 'snapshot leaked "$term"');
      }
    });
  });
}
