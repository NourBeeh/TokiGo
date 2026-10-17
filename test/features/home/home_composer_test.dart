import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/repositories/impl/home_repository_impl.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/features/home/domain/home_composer.dart';
import 'package:tokigo/features/home/domain/home_greeting.dart';

HomeItem item(String id, HomeCardType type, String title) =>
    HomeItem(id: id, type: type, title: title);

HomeSection section(
  String id,
  String title, {
  List<HomeItem> items = const [],
  HomeSectionLayout layout = HomeSectionLayout.horizontal,
}) =>
    HomeSection(id: id, title: title, layout: layout, items: items);

void main() {
  final composer = const HomeComposer();

  final backend = [
    section('trending', 'Trending destinations',
        items: [item('d1', HomeCardType.destination, 'Istanbul')]),
    section('flights', 'Popular flights',
        items: [item('f1', HomeCardType.flight, 'CAI → DXB')]),
    section('hotels', 'Popular hotels',
        items: [item('h1', HomeCardType.hotel, 'Grand Palm')]),
    section('deals', 'Deals',
        items: [item('x1', HomeCardType.deal, 'Weekend deal')]),
    section('experiences', 'Experiences',
        items: [item('e1', HomeCardType.deal, 'Felucca ride')]),
  ];

  final recommendedHotels = [
    item('r1', HomeCardType.hotel, 'Nuitee Cairo'),
    item('r2', HomeCardType.hotel, 'Nuitee Paris'),
  ];

  final recentFlight = RecentSearchSignal(
    kind: 'flight',
    label: 'Cairo → Paris',
    at: DateTime(2026, 9, 1),
  );
  final recentHotel = RecentSearchSignal(
    kind: 'hotel',
    label: 'Hotels in Cairo',
    at: DateTime(2026, 9, 2),
  );

  test('fresh anonymous → discovery-first Home (backend order preserved)',
      () async {
    final out = await composer.compose(HomeCompositionContext(
      userState: HomeUserState.freshAnonymous,
      backendSections: backend,
    ));

    expect(out.sections, hasLength(backend.length));
    expect(out.sections.map((s) => s.id).toList(),
        backend.map((s) => s.id).toList());
    expect(out.sections.every((s) => s.metadata['reason'] == 'discovery'),
        isTrue);
  });

  test('returning anonymous → behavior-first then discovery fallback', () async {
    final out = await composer.compose(HomeCompositionContext(
      userState: HomeUserState.returningAnonymous,
      backendSections: backend,
      recentSearches: [recentFlight, recentHotel],
    ));

    // Behavior section leads.
    expect(out.sections.first.metadata['semanticId'], 'based-on-activity');
    expect(out.sections.first.title, 'Based on what you viewed');
    // Discovery follows in backend order.
    expect(out.sections.skip(1).map((s) => s.id).toList(),
        backend.map((s) => s.id).toList());
    // The behavior items are safe chips: destination-type, no prices.
    final chip = out.sections.first.items.first;
    expect(chip.type, HomeCardType.destination);
    expect(chip.price, isNull);
    expect(chip.metadata['reason'], 'local-behavior');
  });

  test('authenticated → personalized-ready Home with picked-for-you first',
      () async {
    final out = await composer.compose(HomeCompositionContext(
      userState: HomeUserState.authenticated,
      displayName: 'Nour',
      backendSections: backend,
      recommendedHotels: recommendedHotels,
      recentSearches: [recentHotel],
    ));

    expect(out.sections.first.metadata['semanticId'], 'picked-for-you');
    expect(out.sections.first.title, 'Picked for You');
    expect(out.sections.first.items, hasLength(2));
    // Activity section, then deals, then the rest of discovery.
    expect(out.sections[1].metadata['semanticId'], 'based-on-activity');
    expect(out.sections[1].title, 'Based on your recent activity');
    expect(out.sections[2].metadata['semanticId'], 'deals');
    expect(out.sections[2].id, 'deals');
  });

  test('insufficient data → safe discovery fallback (never empty Home)',
      () async {
    // Authenticated but no recommendations and no searches: the deals
    // section still leads (authenticated rule) and the full discovery feed
    // composes right after — never an empty Home.
    final out = await composer.compose(HomeCompositionContext(
      userState: HomeUserState.authenticated,
      backendSections: backend,
    ));

    expect(out.sections, isNotEmpty);
    expect(out.sections.length, backend.length);
    expect(out.sections.first.metadata['semanticId'], 'deals');
    expect(out.sections.first.id, 'deals');
    expect(out.sections.skip(1).every((s) => s.metadata['reason'] == 'discovery'),
        isTrue);

    // Fully empty context — composer output mirrors the (empty) discovery
    // without inventing anything.
    final empty = await composer.compose(const HomeCompositionContext(
      userState: HomeUserState.freshAnonymous,
    ));
    expect(empty.sections, isEmpty);
  });

  test('composer ordering is deterministic (same input → same output)',
      () async {
    final ctx = HomeCompositionContext(
      userState: HomeUserState.authenticated,
      displayName: 'Nour',
      backendSections: backend,
      recommendedHotels: recommendedHotels,
    );
    final a = await composer.compose(ctx);
    final b = await composer.compose(ctx);
    expect(a.sections.map((s) => s.id).toList(),
        b.sections.map((s) => s.id).toList());
    expect(a.sections.map((s) => s.title).toList(),
        b.sections.map((s) => s.title).toList());
  });

  test('composer never invents items — output items come only from inputs',
      () async {
    final out = await composer.compose(HomeCompositionContext(
      userState: HomeUserState.authenticated,
      backendSections: backend,
      recommendedHotels: recommendedHotels,
      recentSearches: [recentFlight],
    ));
    final inputTitles = {
      ...backend.expand((s) => s.items.map((i) => i.title)),
      ...recommendedHotels.map((i) => i.title),
      recentFlight.label,
      recentHotel.label,
    };
    for (final s in out.sections) {
      for (final i in s.items) {
        expect(inputTitles.contains(i.title), isTrue,
            reason: 'unexpected invented item "${i.title}"');
      }
    }
  });

  group('greeting', () {
    test('greeting never contains a hardcoded person name', () {
      final fresh = buildGreeting(
          const HomeCompositionContext(userState: HomeUserState.freshAnonymous));
      final returning = buildGreeting(const HomeCompositionContext(
          userState: HomeUserState.returningAnonymous));
      expect(fresh.title, 'Welcome back');
      expect(returning.title, 'Welcome back');
      // No persona names embedded in any anonymous path.
      expect(fresh.title.toLowerCase(), isNot(contains('samir')));
      expect(fresh.title.toLowerCase(), isNot(contains('nour')));
    });

    test('authenticated greeting uses displayName only when present', () {
      final withName = buildGreeting(const HomeCompositionContext(
        userState: HomeUserState.authenticated,
        displayName: '  Nour  ',
      ));
      expect(withName.title, 'Welcome back, Nour');

      final noName = buildGreeting(const HomeCompositionContext(
        userState: HomeUserState.authenticated,
      ));
      expect(noName.title, 'Welcome back');
      expect(noName.subtitle, 'Trips and ideas picked for you');
    });

    test('greeting is deterministic and separate from product sections', () {
      const ctx = HomeCompositionContext(
        userState: HomeUserState.authenticated,
        displayName: 'Nour',
      );
      final g1 = buildGreeting(ctx);
      final g2 = buildGreeting(ctx);
      expect(g1.title, g2.title);
      expect(g1.subtitle, g2.subtitle);
    });
  });

  group('composer output ↔ Hive snapshot round-trip (Phase 1A codec)', () {
    test('composed sections save and restore via the existing snapshot codec',
        () async {
      final composed = await composer.compose(HomeCompositionContext(
        userState: HomeUserState.authenticated,
        displayName: 'Nour',
        backendSections: backend,
        recommendedHotels: recommendedHotels,
        recentSearches: [recentFlight, recentHotel],
      ));

      // Write via the SAME envelope the controller persists.
      final cache = MemoryOfflineCache();
      await cache.write(
        HomeRepositoryImpl.homeSnapshotCacheKey('user:u-1'),
        <String, dynamic>{
          'schemaVersion': 'home.snapshot.v2',
          'savedAt': DateTime.now().toIso8601String(),
          'audience': 'user:u-1',
          'sections': composed.sections.map(homeSectionToMap).toList(),
        },
      );

      // Read back through the same reader the controller uses.
      final stored = await cache.read(
        HomeRepositoryImpl.homeSnapshotCacheKey('user:u-1'),
      );
      expect(stored, isNotNull);
      final restored = homeSectionsFromMap(stored!);

      expect(restored.length, composed.sections.length);
      expect(restored.first.id, composed.sections.first.id);
      expect(restored.first.title, composed.sections.first.title);
      // Composer metadata (semanticId/reason) survives the round-trip.
      expect(restored.first.metadata['semanticId'], 'picked-for-you');
      expect(
        restored.first.items.first.metadata['reason'],
        composed.sections.first.items.first.metadata['reason'],
      );
      expect(restored.first.items.first.title,
          composed.sections.first.items.first.title);
    });

    test('legacy snapshots (no metadata) still decode — Phase 1A unbroken',
        () async {
      final legacy = <String, dynamic>{
        'sections': [
          {
            'id': 'legacy-1',
            'title': 'Legacy section',
            'layout': 'grid',
            'items': [
              {'id': 'x1', 'type': 'deal', 'title': 'Legacy card'},
            ],
          },
        ],
      };
      final restored = homeSectionsFromMap(legacy);
      expect(restored, hasLength(1));
      expect(restored.first.title, 'Legacy section');
      expect(restored.first.metadata, isEmpty);
      expect(restored.first.items.first.title, 'Legacy card');
      expect(restored.first.items.first.metadata, isEmpty);
    });
  });
}
