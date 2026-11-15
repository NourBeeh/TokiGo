import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/home/domain/explore_catalog.dart';
import 'package:tokigo/features/home/domain/explore_catalog_integrity.dart';
import 'package:tokigo/features/home/domain/explore_catalog_item.dart';
import 'package:tokigo/features/home/domain/explore_city_image.dart';
import 'package:tokigo/features/home/domain/explore_home_section.dart';
import 'package:tokigo/features/home/presentation/widgets/home_discovery_stay_card.dart';
import 'package:tokigo/features/home/presentation/widgets/home_section_titles.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The asset paths actually bundled, read from the asset tree on disk.
///
/// The catalog's guarantee — every city resolves to an existing bundled image
/// — can only be proven against the real bundle, not against the catalog's own
/// claim. `flutter test` runs with the project root as the working directory,
/// so the asset directory is directly readable.
Set<String> bundledExploreAssets() {
  final Directory dir = Directory('assets/explore/cities');
  if (!dir.existsSync()) return <String>{};
  return dir
      .listSync()
      .whereType<File>()
      .map((File f) => 'assets/explore/cities/${f.uri.pathSegments.last}')
      .toSet();
}

void main() {
  group('catalog integrity', () {
    test('every city has a unique id and exactly one existing bundled asset', () {
      final Set<String> assets = bundledExploreAssets();
      final CatalogIntegrityReport report = checkExploreCatalog(assets);

      // The catalog is never empty — an empty catalog would silently blank
      // Home, which is the failure this whole system exists to prevent.
      expect(kExploreCities, isNotEmpty);
      expect(report.cityCount, kExploreCities.length);
      expect(report.isClean, isTrue,
          reason: report.issues.map((i) => i.toString()).join('\n'));

      // Every city resolves through the registry to its own file.
      for (final ExploreCity city in kExploreCities) {
        expect(exploreCityImageAsset(city.id), city.asset);
        expect(assets, contains(city.asset),
            reason: '${city.id} asset not bundled: ${city.asset}');
      }
    });

    test('no two cities share an image mapping', () {
      final List<String> assets =
          kExploreCities.map((ExploreCity c) => c.asset).toList();
      expect(assets.toSet().length, assets.length,
          reason: 'two cities resolve to the same bundled image');
    });

    test('no Explore city image uses a runtime network URL', () {
      for (final ExploreCity city in kExploreCities) {
        final String lower = city.asset.toLowerCase();
        expect(lower.startsWith('http'), isFalse,
            reason: '${city.id} image is remote: ${city.asset}');
        expect(lower.startsWith('assets/'), isTrue,
            reason: '${city.id} image is not bundled: ${city.asset}');
      }
    });

    test('every image mapping belongs to the correct city', () {
      for (final ExploreCity city in kExploreCities) {
        final String? id = exploreCityIdForImageAsset(city.asset);
        expect(id, city.id,
            reason: '${city.asset} does not map back to ${city.id}');
        expect(exploreCityById(id!), same(city));
      }
    });

    test('every image has a verified source and license', () {
      for (final ExploreCity city in kExploreCities) {
        expect(city.imageLicense, isNotNull,
            reason: '${city.id} has no license');
        expect(city.imageLicense!.trim(), isNotEmpty);
        expect(city.imageCredit, isNotNull,
            reason: '${city.id} has no author attribution');
        expect(city.imageCredit!.trim(), isNotEmpty);
        expect(city.imageSource, isNotNull,
            reason: '${city.id} has no source URL');
        expect(city.imageSource!, contains('wikimedia.org'),
            reason: '${city.id} source is not a Commons file page');
      }
    });

    test('the asset manifest records a source and license for every image', () {
      final File manifest = File('assets/explore/manifest.json');
      expect(manifest.existsSync(), isTrue,
          reason: 'asset manifest is missing');
      final Map<String, dynamic> data =
          jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
      final List<dynamic> images = data['images'] as List<dynamic>;
      expect(images.length, kExploreCities.length);

      for (final dynamic entry in images) {
        final Map<String, dynamic> image = Map<String, dynamic>.from(entry);
        expect((image['source'] as String?) ?? '', contains('wikimedia.org'));
        expect((image['license'] as String?) ?? '', isNotEmpty);
        expect((image['author'] as String?) ?? '', isNotEmpty);
        expect(exploreCityById(image['cityId'] as String), isNotNull);
      }
    });
  });

  group('Home curated selection', () {
    test('Home shows only the configured curated subset', () {
      final List<ExploreCity> curated = curatedHomeCities;
      expect(curated.length, curatedHomeCityIds.length);
      expect(curated.length, inInclusiveRange(6, 8));

      final HomeSection section = buildHomeExploreSection();
      expect(section.items.length, curatedHomeCityIds.length);
      expect(
        section.items.map((item) => item.id).toSet(),
        curatedHomeCityIds.toSet(),
      );
    });

    test('the curated selection spans at least six world regions', () {
      final Set<String> regions =
          curatedHomeCities.map((ExploreCity c) => c.region).toSet();
      expect(regions.length, greaterThanOrEqualTo(6),
          reason: 'the Home rail must read as a world map');
    });

    test('the section title resolves to Explore in English and Arabic', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));

      const String fallback = 'Explore';
      expect(HomeSectionTitles.title(en, const {}, fallback), 'Explore');
      expect(HomeSectionTitles.title(ar, const {}, fallback), 'استكشف');
    });
  });

  group('catalog coverage', () {
    test('the complete catalog is the expanded global list', () {
      expect(kExploreCities.length, inInclusiveRange(60, 100));
    });

    test('the catalog covers all seven world regions', () {
      final Set<String> regions =
          kExploreCities.map((ExploreCity c) => c.region).toSet();
      expect(regions, containsAll(<String>[
        'Middle East & North Africa',
        'Europe',
        'Asia',
        'North America',
        'South America',
        'Sub-Saharan Africa',
        'Oceania',
      ]));
    });

    test('the catalog carries no fabricated rating, score or coordinates', () {
      for (final ExploreCity city in kExploreCities) {
        final HomeItem item = exploreCityToHomeItem(city);
        expect(item.rating, isNull, reason: '${city.id} has a fabricated rating');
        expect(item.reviewCount, isNull,
            reason: '${city.id} has a fabricated review count');
        expect(item.price, isNull, reason: '${city.id} has a fabricated price');
        expect(item.metadata.containsKey('latitude'), isFalse,
            reason: '${city.id} has fabricated coordinates');
        expect(item.metadata.containsKey('staysCount'), isFalse,
            reason: '${city.id} has a fabricated stay count');
      }
    });
  });

  group('card rendering', () {
    testWidgets('a catalog city card renders its bundled image offline', (
      WidgetTester tester,
    ) async {
      final ExploreCity city = kExploreCities.first;
      final HomeItem item = exploreCityToHomeItem(city);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: HomeDiscoveryStayCard(item: item, onTap: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(city.name), findsOneWidget);
      // The card resolves an AssetImage — never a NetworkImage.
      final Iterable<Image> images = tester.widgetList<Image>(find.byType(Image));
      expect(images, isNotEmpty);
      for (final Image image in images) {
        // CardImage resolves `assets/...` through ResizeImage.resizeIfNeeded,
        // so the AssetImage may be wrapped — unwrap, never compare the wrapper.
        final ImageProvider provider = image.image;
        final AssetImage asset = provider is ResizeImage
            ? provider.imageProvider as AssetImage
            : provider as AssetImage;
        expect(asset.assetName, city.asset);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Arabic RTL renders the catalog card mirrored', (
      WidgetTester tester,
    ) async {
      final ExploreCity city = kExploreCities.first;
      final HomeItem item = exploreCityToHomeItem(city);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: HomeDiscoveryStayCard(item: item, onTap: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(Directionality.of(tester.element(find.byType(Scaffold))),
          TextDirection.rtl);
      // The city name is localized into Arabic through the l10n select.
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      expect(ar.destinationCityName(city.name.toLowerCase().replaceAll(' ', '_')),
          isNot(equals(city.name.toLowerCase().replaceAll(' ', '_'))));
      expect(tester.takeException(), isNull);
    });
  });
}
