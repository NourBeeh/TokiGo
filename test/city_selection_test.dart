import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/geo/city_catalog.dart';
import 'package:tokigo/core/geo/city_detection_service.dart';
import 'package:tokigo/core/geo/city_selection.dart';
import 'package:tokigo/core/geo/geo_client.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';

const CityOption _london = CityOption(
  id: 'london',
  name: 'London',
  countryCode: 'GB',
  currency: 'GBP',
  latitude: 51.5072,
  longitude: -0.1276,
  aliases: <String>['لندن'],
);

const CityOption _cairo = CityOption(
  id: 'cairo',
  name: 'Cairo',
  countryCode: 'EG',
  currency: 'EGP',
  latitude: 30.0444,
  longitude: 31.2357,
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('CityCatalog', () {
    test('parses only valid records and searches name/country', () {
      final CityCatalog? catalog = CityCatalog.tryParse(<String, dynamic>{
        'version': 3,
        'cities': <Map<String, dynamic>>[
          _london.toMap(),
          _cairo.toMap(),
          <String, dynamic>{'id': '', 'name': 'Broken'},
        ],
      });

      expect(catalog, isNotNull);
      expect(catalog!.version, 3);
      expect(catalog.cities, hasLength(2));
      expect(catalog.search('lon').single.id, 'london');
      expect(catalog.search('EG').single.id, 'cairo');
      expect(
        catalog.search('لندن').single.id,
        'london',
        reason: 'the picker must be searchable by local city names',
      );
      expect(
        catalog.cities.firstWhere((CityOption city) => city.id == 'london').aliases,
        contains('لندن'),
        reason: 'aliases survive the cache round-trip',
      );
      expect(
        catalog
            .search(
              'united kingdom',
              countryName: (String code) =>
                  code == 'GB' ? 'United Kingdom' : 'Egypt',
            )
            .single
            .id,
        'london',
      );
      expect(catalog.search('nowhere'), isEmpty);
    });

    test('a catalog with no valid city is rejected', () {
      expect(
        CityCatalog.tryParse(<String, dynamic>{
          'cities': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'x', 'name': 'X'},
          ],
        }),
        isNull,
      );
    });
  });

  group('CitySelectionController', () {
    test('a manual city is persisted and never overwritten by detection',
        () async {
      final cache = MemoryOfflineCache();
      final container = ProviderContainer(
        overrides: <Override>[
          offlineCacheProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);

      container.read(citySelectionProvider);
      await _settle();

      await container.read(citySelectionProvider.notifier).selectManual(_london);
      expect(container.read(effectiveCityProvider)?.id, 'london');
      expect(container.read(effectiveCityCurrencyProvider), 'GBP');
      expect(container.read(hasManualCityProvider), isTrue);

      await container
          .read(citySelectionProvider.notifier)
          .setAutomatic(_cairo, source: CitySelectionSource.ip);

      expect(container.read(effectiveCityProvider)?.id, 'london');
      expect(
        container.read(citySelectionProvider).automatic?.city.id,
        isNull,
        reason: 'a manual choice must block the automatic write entirely',
      );

      final stored = await cache.read(CitySelectionController.manualKey);
      expect(stored?['selection'], isA<Map<String, dynamic>>());
    });

    test('a persisted manual choice is restored before detection runs',
        () async {
      final cache = MemoryOfflineCache();
      await cache.write(CitySelectionController.manualKey, <String, dynamic>{
        'selection': SelectedCity(
          city: _cairo,
          source: CitySelectionSource.manual,
          updatedAt: DateTime.utc(2026, 1, 1),
        ).toMap(),
      });

      final container = ProviderContainer(
        overrides: <Override>[
          offlineCacheProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);
      container.read(citySelectionProvider);
      await _settle();

      expect(container.read(citySelectionProvider).status,
          CitySelectionStatus.ready);
      expect(container.read(effectiveCityProvider)?.id, 'cairo');
      expect(container.read(hasManualCityProvider), isTrue);
    });

    test('without any choice the state is honestly unavailable', () async {
      final container = ProviderContainer(
        overrides: <Override>[
          offlineCacheProvider.overrideWithValue(MemoryOfflineCache()),
        ],
      );
      addTearDown(container.dispose);
      container.read(citySelectionProvider);
      await _settle();

      expect(container.read(citySelectionProvider).status,
          CitySelectionStatus.unavailable);
      expect(container.read(effectiveCityProvider), isNull);
    });
  });

  group('CityDetectionService', () {
    test('resolves once, respects the cooldown and maps the source', () async {
      DateTime clock = DateTime.utc(2026, 1, 1);
      int calls = 0;
      CityOption? resolved;
      CitySelectionSource? source;

      final service = CityDetectionService(
        locate: () async {
          calls += 1;
          return const GeoLocatedCity(
            cityId: 'london',
            city: 'London',
            countryCode: 'GB',
            currency: 'GBP',
            latitude: 51.5072,
            longitude: -0.1276,
            source: 'gps',
          );
        },
        currentAutomatic: () => null,
        onResolved: (CityOption city, CitySelectionSource value) async {
          resolved = city;
          source = value;
        },
        now: () => clock,
      );

      final CityOption? first = await service.detectIfNeeded();
      expect(first?.id, 'london');
      expect(resolved?.id, 'london');
      expect(source, CitySelectionSource.gps);

      expect(await service.detectIfNeeded(), isNull);
      expect(calls, 1);

      clock = clock.add(CityDetectionService.cooldown);
      await service.detectIfNeeded();
      expect(calls, 2);
    });

    test('an IP result is labelled as such and failures are silent', () async {
      CitySelectionSource? source;
      final service = CityDetectionService(
        locate: () async => const GeoLocatedCity(
          cityId: 'cairo',
          city: 'Cairo',
          countryCode: 'EG',
          currency: 'EGP',
          latitude: 30.0444,
          longitude: 31.2357,
          source: 'ip',
        ),
        currentAutomatic: () => null,
        onResolved: (CityOption city, CitySelectionSource value) async {
          source = value;
        },
      );

      await service.detectIfNeeded();
      expect(source, CitySelectionSource.ip);

      final failing = CityDetectionService(
        locate: () async => throw StateError('offline'),
        currentAutomatic: () => null,
        onResolved: (CityOption city, CitySelectionSource value) async {
          fail('a failed lookup must not resolve a city');
        },
      );
      expect(await failing.detectIfNeeded(), isNull);
    });
  });
}
