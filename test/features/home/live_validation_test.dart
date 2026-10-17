import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/core/repositories/impl/home_repository_impl.dart'
    show homeSectionToMap, homeSectionsFromMap;
import 'package:tokigo/features/booking/application/services/offer_revalidation_service.dart';
import 'package:tokigo/features/home/application/home_live_validation_service.dart';
import 'package:tokigo/features/home/domain/home_composer.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';

/// Scripted revalidation behaviour: maps offerId → outcome; unmapped ids
/// throw (transport failure); `status == error` throws (network failure).
class _ScriptedRevalidation implements OfferRevalidationService {
  final Map<String, RevalidationOutcome> _scripted = <String, RevalidationOutcome>{};
  final List<String> calls = <String>[];

  void script(String offerId, RevalidationOutcome outcome) {
    _scripted[offerId] = outcome;
  }

  @override
  Future<RevalidationOutcome> revalidate({
    required String offerId,
    required String providerId,
    required String offerType,
    double? knownPrice,
    int? guests,
  }) async {
    calls.add(offerId);
    final outcome = _scripted[offerId];
    if (outcome == null) {
      throw TimeoutException('provider timeout');
    }
    if (outcome.status == RevalidationStatus.error) {
      throw const ApiNetworkError(message: 'socket closed');
    }
    return outcome;
  }
}

RevalidationOutcome ok({double? price, String? expiresAt}) =>
    RevalidationOutcome(
      status: RevalidationStatus.ok,
      price: price,
      currency: 'USD',
      expiresAt: expiresAt,
    );

RevalidationOutcome changed(double newPrice) => RevalidationOutcome(
      status: RevalidationStatus.priceChanged,
      newPrice: newPrice,
      currency: 'USD',
    );

const RevalidationOutcome unavailable = RevalidationOutcome(
  status: RevalidationStatus.unavailable,
  reason: 'sold out',
);

HomeItem bookableHotel(
  String id, {
  double? price,
  String? providerOfferId,
  DateTime? validUntil,
}) {
  final expiryIso = validUntil?.toIso8601String();
  return HomeItem(
    id: id,
    type: HomeCardType.hotel,
    title: 'Hotel $id',
    price: price,
    currency: 'USD',
    metadata: <String, dynamic>{
      'providerId': 'nuitee',
      'providerOfferId': providerOfferId ?? id,
      if (expiryIso != null) 'validUntil': expiryIso,
    },
  );
}

HomeItem bookableFlight(String id, {double? price}) => HomeItem(
      id: id,
      type: HomeCardType.flight,
      title: 'Flight $id',
      price: price,
      currency: 'USD',
      metadata: <String, dynamic>{
        'providerId': 'duffel-flight',
        'providerOfferId': id,
      },
    );

HomeItem discoveryCard(String id) => HomeItem(
      id: id,
      type: HomeCardType.destination,
      title: 'Destination $id',
      metadata: const <String, dynamic>{}, // No provider identity.
    );

HomeSection sectionWith(List<HomeItem> items) => HomeSection(
      id: 's1',
      title: 'Hotels',
      layout: HomeSectionLayout.horizontalPeek,
      items: items,
    );

Future<void> settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// In-memory snapshot fake repository (mirrors the real envelope/codec).
class _FakeRepo implements HomeRepository {
  final Map<String, Map<String, dynamic>> _snapshots = <String, Map<String, dynamic>>{};

  ApiResult<List<HomeSection>> networkResult =
      const ApiResult.failure(ApiNetworkError(message: 'offline'));

  /// When set, [getHomeSections] awaits this future (slow-network tests).
  Future<ApiResult<List<HomeSection>>>? networkOverride;

  @override
  Future<ApiResult<List<HomeSection>>> getHomeSections() async =>
      networkOverride ?? networkResult;

  @override
  Future<ApiResult<List<HomeItem>>> getRecommendedHotels({int limit = 6}) async =>
      const ApiResult.success([]);

  @override
  Future<ApiResult<void>> refresh() async => ApiResult.success(null);

  @override
  Future<List<HomeSection>?> readHomeSnapshot({required String audience}) async {
    final map = _snapshots['home|snapshot|$audience'];
    if (map == null) return null;
    final sections = _decodeSections(map['sections']);
    return sections.isEmpty ? null : sections;
  }

  @override
  Future<void> saveHomeSnapshot(List<HomeSection> sections,
      {required String audience}) async {
    _snapshots['home|snapshot|$audience'] = {
      'schemaVersion': 'home.snapshot.v2',
      'savedAt': DateTime.now().toIso8601String(),
      'audience': audience,
      'sections': _encodeSections(sections),
    };
  }

  @override
  Future<void> clearHomeSnapshot({required String audience}) async {
    _snapshots.remove('home|snapshot|$audience');
  }

  Future<void> seed(List<HomeSection> sections, String audience) =>
      saveHomeSnapshot(sections, audience: audience);

  Map<String, dynamic>? rawSnapshot(String audience) =>
      _snapshots['home|snapshot|$audience'];

  // Codec: reuse the REAL repository codec (already tested in 1B/1C) so the
  // snapshot round-trip in these tests cannot drift from production.
  List<Map<String, dynamic>> _encodeSections(List<HomeSection> sections) =>
      sections.map(homeSectionToMap).toList();

  List<HomeSection> _decodeSections(dynamic raw) {
    if (raw is! List) return const [];
    return homeSectionsFromMap({'sections': raw});
  }
}

void main() {
  group('Validation statuses (service)', () {
    test('valid offer: live price/expiry returned', () async {
      final revalidation = _ScriptedRevalidation();
      revalidation.script('h1', ok(price: 99, expiresAt: '2030-01-01T00:00:00Z'));
      final service = HomeLiveValidationService(revalidation);

      final results = await service
          .validate([sectionWith([bookableHotel('h1', price: 120)])]);

      expect(results.single.status, LiveValidationStatus.valid);
      expect(results.single.currentPrice, 99);
      expect(results.single.expiresAt, '2030-01-01T00:00:00Z');
      expect(revalidation.calls, ['h1']);
    });

    test('price changed: cached price never treated as live', () async {
      final revalidation = _ScriptedRevalidation();
      revalidation.script('h1', changed(250));
      final service = HomeLiveValidationService(revalidation);

      final results = await service
          .validate([sectionWith([bookableHotel('h1', price: 120)])]);

      expect(results.single.status, LiveValidationStatus.priceChanged);
      expect(results.single.needsReplacement, isTrue);
    });

    test('unavailable: reported as needing replacement', () async {
      final revalidation = _ScriptedRevalidation();
      revalidation.script('h1', unavailable);
      final service = HomeLiveValidationService(revalidation);

      final results = await service.validate([sectionWith([bookableHotel('h1')])]);

      expect(results.single.status, LiveValidationStatus.unavailable);
      expect(results.single.availability, false);
    });

    test('expired (local metadata): zero network calls', () async {
      final revalidation = _ScriptedRevalidation();
      final service = HomeLiveValidationService(revalidation);

      final results = await service.validate([
        sectionWith([
          bookableHotel('h1',
              validUntil: DateTime.now().subtract(const Duration(days: 1))),
        ]),
      ]);

      expect(results.single.status, LiveValidationStatus.expired);
      expect(revalidation.calls, isEmpty);
    });

    test('provider failure → validationFailed (product NOT invalid)', () async {
      final revalidation = _ScriptedRevalidation(); // Nothing scripted → throws.
      final service = HomeLiveValidationService(revalidation);

      final results = await service.validate([sectionWith([bookableHotel('h1')])]);

      expect(results.single.status, LiveValidationStatus.validationFailed);
      expect(results.single.keepCached, isTrue);
      expect(results.single.needsReplacement, isFalse);
    });

    test('unsupported: discovery cards skipped entirely', () async {
      final revalidation = _ScriptedRevalidation();
      final service = HomeLiveValidationService(revalidation);

      final results = await service.validate([
        sectionWith([discoveryCard('d1'), discoveryCard('d2')]),
      ]);

      expect(results, isEmpty);
      expect(revalidation.calls, isEmpty);
    });

    test('dedupe: same offer identity validated exactly once', () async {
      final revalidation = _ScriptedRevalidation();
      revalidation.script('same-id', ok(price: 10));
      final service = HomeLiveValidationService(revalidation);

      await service.validate([
        sectionWith([bookableHotel('a', providerOfferId: 'same-id')]),
        sectionWith([bookableHotel('b', providerOfferId: 'same-id')]),
      ]);

      expect(revalidation.calls, ['same-id']);
    });

    test('one provider failure does not break the other products', () async {
      final revalidation = _ScriptedRevalidation();
      revalidation.script('h1', ok(price: 50)); // h2 unmapped → throws.
      final service = HomeLiveValidationService(revalidation);

      final results =
          await service.validate([sectionWith([bookableHotel('h1'), bookableHotel('h2')])]);

      final statuses = results.map((r) => r.status).toSet();
      expect(statuses, contains(LiveValidationStatus.valid));
      expect(statuses, contains(LiveValidationStatus.validationFailed));
      expect(results, hasLength(2));
    });

    test('malformed outcome (error status) → keep semantics', () async {
      final revalidation = _ScriptedRevalidation();
      revalidation.script('h1', const RevalidationOutcome(
        status: RevalidationStatus.error,
        reason: 'Unexpected response',
      ));
      final service = HomeLiveValidationService(revalidation);

      final results = await service.validate([sectionWith([bookableHotel('h1')])]);

      expect(results.single.status, LiveValidationStatus.validationFailed);
      expect(results.single.keepCached, isTrue);
    });
  });

  group('Snapshot + replacement (controller)', () {
    test('cached snapshot renders FIRST; validation runs afterwards', () async {
      final revalidation = _ScriptedRevalidation();
      revalidation.script('h1', changed(500));
      // GATED network AND gated validation: while both are pending the ONLY
      // possible state change is the snapshot restore — proving the cached
      // Home renders before any network/validation completes.
      final network = Completer<ApiResult<List<HomeSection>>>();
      final repo = _FakeRepo();
      repo.networkOverride = network.future;
      final validationGate = Completer<void>();
      final slow = _GatedRevalidation(revalidation, validationGate);
      await repo.seed([sectionWith([bookableHotel('h1', price: 120)])], 'anon');

      final controller = HomeController(
        repo,
        audience: 'anon',
        liveValidation: HomeLiveValidationService(slow),
      );

      await settle();
      expect(controller.state.status, HomeStatus.success);
      expect(controller.state.fromCache, isTrue);
      expect(controller.state.sections.first.items.first.price, 120);
      expect(revalidation.calls, ['h1']); // Validation STARTED (in background).

      // Release the validation: the changed product is removed and the
      // updated snapshot persisted.
      validationGate.complete();
      network.complete(
          const ApiResult.failure(ApiNetworkError(message: 'offline')));
      await settle();

      final persisted = await repo.readHomeSnapshot(audience: 'anon');
      expect(persisted!.first.items, isEmpty);
    });

    test('invalid hotel gets a REAL replacement (no invented candidate)',
        () async {
      final revalidation = _ScriptedRevalidation();
      revalidation.script('h1', unavailable);
      final repo = _FakeRepo();
      await repo.seed([sectionWith([bookableHotel('h1', price: 120)])], 'anon');

      const realCandidate = RankedCandidate(
        id: 'real-c2',
        title: 'Nuitee Real Hotel',
        price: 130,
        reason: 'recommendation',
        source: 'recommendation',
      );

      final controller = HomeController(
        repo,
        audience: 'anon',
        liveValidation: HomeLiveValidationService(revalidation),
        contextBuilder: (recommended) async => const HomeCompositionContext(
          userState: HomeUserState.freshAnonymous,
          rankedCandidates: [realCandidate],
        ),
      );
      await settle();

      final items = controller.state.sections.first.items;
      expect(items, hasLength(1));
      expect(items.first.id, 'real-c2');
      expect(items.first.title, 'Nuitee Real Hotel');
      expect(items.first.price, 130);
      // Provenance preserved.
      expect(items.first.metadata['source'], 'recommendation');
      expect(items.first.metadata['providerOfferId'], 'real-c2');
      expect(items.first.metadata['replacedAt'], isNotNull);
    });

    test('invalid flight gets a real replacement (same placement type)',
        () async {
      final revalidation = _ScriptedRevalidation();
      revalidation.script('f1', changed(999));
      final repo = _FakeRepo();
      await repo.seed([sectionWith([bookableFlight('f1', price: 200)])], 'anon');

      const replacement = RankedCandidate(
        id: 'flight-c9',
        title: 'Live Duffel Flight',
        reason: 'recommendation',
      );

      final controller = HomeController(
        repo,
        audience: 'anon',
        liveValidation: HomeLiveValidationService(revalidation),
        contextBuilder: (recommended) async => const HomeCompositionContext(
          userState: HomeUserState.freshAnonymous,
          rankedCandidates: [replacement],
        ),
      );
      await settle();

      final item = controller.state.sections.first.items.single;
      expect(item.id, 'flight-c9');
      expect(item.type, HomeCardType.flight);
      expect(item.title, 'Live Duffel Flight');
    });

    test('unchanged (valid) products preserved with refreshed price',
        () async {
      final revalidation = _ScriptedRevalidation();
      revalidation.script('h1', ok(price: 77));
      final repo = _FakeRepo();
      await repo.seed(
        [
          sectionWith([
            bookableHotel('h1', price: 80),
            discoveryCard('d1'),
          ]),
        ],
        'anon',
      );

      final controller = HomeController(
        repo,
        audience: 'anon',
        liveValidation: HomeLiveValidationService(revalidation),
      );
      await settle();

      final items = controller.state.sections.first.items;
      expect(items, hasLength(2));
      final hotel = items.firstWhere((i) => i.id == 'h1');
      expect(hotel.price, 77);
      expect(hotel.metadata['validatedAt'], isNotNull);
      expect(items.firstWhere((i) => i.id == 'd1').title, 'Destination d1');
    });

    test('replacement never duplicates a product already on screen', () async {
      final revalidation = _ScriptedRevalidation();
      revalidation.script('h1', unavailable);
      final repo = _FakeRepo();
      await repo.seed(
        [
          sectionWith([
            bookableHotel('h1'),
            bookableHotel('visible'),
          ]),
        ],
        'anon',
      );

      final controller = HomeController(
        repo,
        audience: 'anon',
        liveValidation: HomeLiveValidationService(revalidation),
        contextBuilder: (recommended) async => const HomeCompositionContext(
          userState: HomeUserState.freshAnonymous,
          rankedCandidates: [
            RankedCandidate(id: 'visible', title: 'Already Visible'), // Skipped.
            RankedCandidate(id: 'fresh', title: 'Fresh Real Option'),
          ],
        ),
      );
      await settle();

      final ids = controller.state.sections.first.items.map((i) => i.id);
      expect(ids, contains('visible'));
      expect(ids, contains('fresh'));
      expect(ids, isNot(contains('h1')));
      expect(controller.state.sections.first.items, hasLength(2));
    });

    test('sensitive data absent from the persisted validated snapshot',
        () async {
      final revalidation = _ScriptedRevalidation();
      revalidation.script('h1', ok(price: 10));
      final repo = _FakeRepo();
      await repo.seed([sectionWith([bookableHotel('h1')])], 'anon');

      final controller = HomeController(
        repo,
        audience: 'anon',
        liveValidation: HomeLiveValidationService(revalidation),
      );
      await settle();

      final map = repo.rawSnapshot('anon');
      expect(map, isNotNull);
      final serialized = map.toString();
      const forbidden = ['sk-or-', 'Bearer', 'password', 'accessToken', '@gmail'];
      for (final term in forbidden) {
        expect(serialized.contains(term), isFalse,
            reason: 'snapshot leaked "$term"');
      }
    });
  });

  group('Failure safety', () {
    test('provider timeout does not break Home (content survives)', () async {
      final revalidation = _ScriptedRevalidation(); // All calls throw.
      final repo = _FakeRepo();
      await repo.seed([sectionWith([bookableHotel('h1', price: 100)])], 'anon');

      final controller = HomeController(
        repo,
        audience: 'anon',
        liveValidation: HomeLiveValidationService(revalidation),
      );
      await settle();

      // Background network refresh failed (offline repo) BUT the cached
      // content survives — partial, never error. Live validation failing on
      // top of that must not change anything either.
      expect(controller.state.status, HomeStatus.partial);
      final item = controller.state.sections.first.items.single;
      expect(item.id, 'h1');
      expect(item.price, 100);
      expect(item.metadata.containsKey('validatedAt'), isFalse);
    });

    test('no state update after dispose', () async {
      final revalidation = _ScriptedRevalidation();
      revalidation.script('h1', unavailable);
      final repo = _FakeRepo();
      await repo.seed([sectionWith([bookableHotel('h1')])], 'anon');

      // Hold the validation in flight so dispose lands BEFORE it resolves.
      final slow = _SlowRevalidation(revalidation);
      final controller = HomeController(
        repo,
        audience: 'anon',
        liveValidation: HomeLiveValidationService(slow),
      );
      await Future<void>.delayed(Duration.zero);
      // Snapshot published + validation started but still gated.
      expect(controller.mounted, isTrue);
      controller.dispose();
      expect(controller.mounted, isFalse);

      slow.release(); // Validation now completes — must be a silent no-op.
      await settle();

      // The mounted guard prevented any post-dispose write: the persisted
      // snapshot still carries the ORIGINAL cached item untouched.
      final persisted = await repo.readHomeSnapshot(audience: 'anon');
      expect(persisted!.first.items.single.id, 'h1');
      expect(
        persisted.first.items.single.metadata.containsKey('replacedAt'),
        isFalse,
      );
    });

    test('duplicate validation jobs prevented (single pass per snapshot)',
        () async {
      final revalidation = _ScriptedRevalidation();
      revalidation.script('h1', ok(price: 10));
      final repo = _FakeRepo();
      await repo.seed([sectionWith([bookableHotel('h1')])], 'anon');

      // SLOW provider: hold every revalidate until released.
      final slow = _SlowRevalidation(revalidation);
      final controller = HomeController(
        repo,
        audience: 'anon',
        liveValidation: HomeLiveValidationService(slow),
      );
      await Future<void>.delayed(Duration.zero);

      // While the first validation is in flight, a restore/load cycle
      // triggers the guard again — the in-flight flag must no-op it.
      await controller.restoreFromSnapshot();
      slow.release();
      await settle();

      expect(revalidation.calls.length, lessThanOrEqualTo(1));
    });
  });

  group('Personalization preservation', () {
    test('authenticated replacement keeps the personalized provenance',
        () async {
      final revalidation = _ScriptedRevalidation();
      revalidation.script('h1', unavailable);
      final repo = _FakeRepo();
      await repo.seed([sectionWith([bookableHotel('h1')])], 'user:u-1');

      const personalized = RankedCandidate(
        id: 'p-1',
        title: 'Personalized Pick',
        reason: 'recent_search',
        source: 'local',
        confidence: 0.9,
      );

      final controller = HomeController(
        repo,
        audience: 'user:u-1',
        liveValidation: HomeLiveValidationService(revalidation),
        contextBuilder: (recommended) async => const HomeCompositionContext(
          userState: HomeUserState.authenticated,
          displayName: 'Nour',
          rankedCandidates: [personalized],
        ),
      );
      await settle();

      final item = controller.state.sections.first.items.single;
      expect(item.id, 'p-1');
      expect(item.metadata['reason'], 'recent_search');
      expect(item.metadata['source'], 'local');
      expect(item.metadata['confidence'], 0.9);
    });

    test('anonymous flow remains local/discovery (no sensitive rails)',
        () async {
      final revalidation = _ScriptedRevalidation();
      revalidation.script('h1', unavailable);
      final repo = _FakeRepo();
      await repo.seed(
        [sectionWith([bookableHotel('h1'), discoveryCard('d1')])],
        'anon',
      );

      final controller = HomeController(
        repo,
        audience: 'anon',
        liveValidation: HomeLiveValidationService(revalidation),
        contextBuilder: (recommended) async => const HomeCompositionContext(
          userState: HomeUserState.returningAnonymous, // No candidates.
        ),
      );
      await settle();

      final items = controller.state.sections.first.items;
      expect(items.map((i) => i.id), ['d1']);
    });

    test('personalization disabled remains discovery-safe', () async {
      final revalidation = _ScriptedRevalidation();
      revalidation.script('h1', unavailable);
      final repo = _FakeRepo();
      await repo.seed([sectionWith([bookableHotel('h1')])], 'anon');

      final controller = HomeController(
        repo,
        audience: 'anon',
        liveValidation: HomeLiveValidationService(revalidation),
        contextBuilder: (recommended) async => const HomeCompositionContext(
          userState: HomeUserState.authenticated,
          personalizationEnabled: false, // Opted out.
          rankedCandidates: [
            RankedCandidate(id: 'x', title: 'Safe Pick', reason: 'recommendation'),
          ],
        ),
      );
      await settle();

      final item = controller.state.sections.first.items.single;
      expect(item.id, 'x');
      expect(item.metadata['reason'], 'recommendation'); // Neutral reason only.
    });
  });
}

/// Wraps a scripted service with a manual gate: every call records the id
/// immediately, then waits for [gate] before resolving.
class _GatedRevalidation implements OfferRevalidationService {
  _GatedRevalidation(this._inner, this.gate);

  final _ScriptedRevalidation _inner;
  final Completer<void> gate;

  @override
  Future<RevalidationOutcome> revalidate({
    required String offerId,
    required String providerId,
    required String offerType,
    double? knownPrice,
    int? guests,
  }) async {
    _inner.calls.add(offerId); // Recorded BEFORE the gate — proves start.
    await gate.future;
    return _inner.revalidate(
      offerId: offerId,
      providerId: providerId,
      offerType: offerType,
      knownPrice: knownPrice,
      guests: guests,
    );
  }
}

/// Wraps a scripted service with a manual gate: every call waits for
/// [release] before resolving (used to hold validation in flight).
class _SlowRevalidation implements OfferRevalidationService {
  _SlowRevalidation(this._inner);

  final _ScriptedRevalidation _inner;
  final Completer<void> _gate = Completer<void>();

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<RevalidationOutcome> revalidate({
    required String offerId,
    required String providerId,
    required String offerType,
    double? knownPrice,
    int? guests,
  }) async {
    await _gate.future;
    return _inner.revalidate(
      offerId: offerId,
      providerId: providerId,
      offerType: offerType,
      knownPrice: knownPrice,
      guests: guests,
    );
  }
}
