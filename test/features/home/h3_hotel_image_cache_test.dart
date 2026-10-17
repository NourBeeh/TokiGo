import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/features/home/application/hotel_image_cache.dart';
import 'package:tokigo/features/home/presentation/widgets/cached_hotel_image.dart';

/// H3 — Hive-backed hotel image cache tests (LRU + TTL + widget pipeline).
void main() {
  group('HotelImageCache (service)', () {
    test('write → read round-trips the exact bytes', () async {
      final cache = HotelImageCache(MemoryOfflineCache());
      final bytes = await _pngBytes();

      await cache.write('https://x/hotel.jpg', bytes);
      final read = await cache.read('https://x/hotel.jpg');

      expect(read, isNotNull);
      expect(read, equals(bytes));
    });

    test('read of a missing url is a null miss', () async {
      final cache = HotelImageCache(MemoryOfflineCache());
      expect(await cache.read('https://x/missing.jpg'), isNull);
    });

    test('TTL: entries older than 7 days are evicted on read', () async {
      var now = DateTime(2026, 1, 1);
      final cache = HotelImageCache(MemoryOfflineCache(), now: () => now);

      await cache.write('https://x/stale.jpg', await _pngBytes());

      // 8 days later — beyond the TTL.
      now = DateTime(2026, 1, 9);
      expect(await cache.read('https://x/stale.jpg'), isNull);
    });

    test('TTL: fresh entries (6 days) survive', () async {
      var now = DateTime(2026, 1, 1);
      final cache = HotelImageCache(MemoryOfflineCache(), now: () => now);

      final bytes = await _pngBytes();
      await cache.write('https://x/fresh.jpg', bytes);

      now = DateTime(2026, 1, 7); // 6 days — still alive.
      expect(await cache.read('https://x/fresh.jpg'), equals(bytes));
    });

    test('LRU: writing the 31st image evicts the least-recently-used',
        () async {
      var now = DateTime(2026, 1, 1);
      final cache = HotelImageCache(MemoryOfflineCache(), now: () => now);

      // Fill the cache to the cap.
      for (var i = 0; i < 30; i++) {
        await cache.write('https://x/img-$i.jpg', await _pngBytes());
        now = now.add(const Duration(minutes: 1));
      }

      // Touch img-0 so img-1 becomes the least-recently-used.
      await cache.read('https://x/img-0.jpg');
      now = now.add(const Duration(minutes: 1));

      // One more write → eviction brings the count back to 30.
      await cache.write('https://x/img-30.jpg', await _pngBytes());

      expect(await cache.read('https://x/img-1.jpg'), isNull, // evicted LRU
          reason: 'img-1 was the least recently used after img-0 was touched');
      expect(await cache.read('https://x/img-0.jpg'), isNotNull);
      expect(await cache.read('https://x/img-30.jpg'), isNotNull);
    });

    test('malformed entries are tolerated as misses, never throw', () async {
      final store = MemoryOfflineCache();
      await store.write('hotel_image|https://x/broken.jpg', {
        'bytes': 'not-bytes',
        'cachedAt': 'not-a-date',
      });
      final cache = HotelImageCache(store);

      expect(await cache.read('https://x/broken.jpg'), isNull);
    });

    test('clear removes only hotel image entries', () async {
      final store = MemoryOfflineCache();
      final cache = HotelImageCache(store);
      await cache.write('https://x/a.jpg', await _pngBytes());
      await store.write('home|sections', {'sections': []});

      await cache.clear();

      expect(await cache.read('https://x/a.jpg'), isNull);
      expect(await store.contains('home|sections'), isTrue);
    });
  });

  group('CachedHotelImage (widget)', () {
    setUp(() async {
      await debugDrainInFlight();
    });

    Widget host(CachedHotelImage image) => MaterialApp(home: Scaffold(body: image));

    /// Pumps frames long enough for async loads to land WITHOUT settling —
    /// the shimmer pulses forever (ShimmerBox repeats), so pumpAndSettle
    /// would hang while a placeholder is on screen.
    Future<void> pumpLoads(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('miss → shimmer, then fetch → store → render', (tester) async {
      final store = MemoryOfflineCache();
      final cache = HotelImageCache(store);
      final bytes = await _pngBytes();
      var fetches = 0;

      await tester.pumpWidget(host(CachedHotelImage(
        url: 'https://x/hotel.jpg',
        cache: cache,
        httpClient: (_) async {
          fetches++;
          return bytes;
        },
      )));

      // First frame: shimmer placeholder (cache miss, fetch in flight).
      expect(find.byType(CachedHotelImage), findsOneWidget);
      await pumpLoads(tester);

      // Image rendered from the fetched bytes (ResizeImage wraps the
      // MemoryImage per the P2 cacheWidth decode contract).
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<ResizeImage>());
      expect((image.image as ResizeImage).imageProvider, isA<MemoryImage>());

      // Bytes were stored into the cache for the next cold start.
      final stored = await cache.read('https://x/hotel.jpg');
      expect(stored, equals(bytes));
      expect(fetches, 1);
    });

    testWidgets('second mount with warm cache renders instantly (no fetch)',
        (tester) async {
      final store = MemoryOfflineCache();
      final cache = HotelImageCache(store);
      final bytes = await _pngBytes();

      // Warm the cache once.
      await cache.write('https://x/warm.jpg', bytes);
      var fetches = 0;

      await tester.pumpWidget(host(CachedHotelImage(
        url: 'https://x/warm.jpg',
        cache: cache,
        httpClient: (_) async {
          fetches++;
          return await _pngBytes();
        },
      )));
      await pumpLoads(tester);

      // Cache hit — no fetch ever happened (bytes under the P2 ResizeImage).
      expect(fetches, 0);
      final image = tester.widget<Image>(find.byType(Image));
      final memory = (image.image as ResizeImage).imageProvider as MemoryImage;
      expect(memory.bytes, equals(bytes));
    });

    testWidgets('P2: decode is sized to the display resolution (cacheWidth)',
        (tester) async {
      final cache = HotelImageCache(MemoryOfflineCache());

      await tester.pumpWidget(host(CachedHotelImage(
        url: 'https://x/sized.jpg',
        cache: cache,
        httpClient: (_) async => await _pngBytes(),
      )));
      await pumpLoads(tester);

      // P2 contract: the decoded image provider is a ResizeImage wrapping the
      // memory bytes at display resolution (Image.memory(cacheWidth:) builds
      // exactly this shape).
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<ResizeImage>());
      final resize = image.image as ResizeImage;
      expect(resize.width, isNotNull);
      expect(resize.height, isNull); // height unconstrained, aspect intact.
    });

    testWidgets('fetch failure keeps the shimmer (never throws)', (tester) async {
      final cache = HotelImageCache(MemoryOfflineCache());

      await tester.pumpWidget(host(CachedHotelImage(
        url: 'https://x/dead.jpg',
        cache: cache,
        httpClient: (_) async => null, // network failed.
      )));
      await pumpLoads(tester);

      // No crash, no Image widget — graceful degradation.
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Minimal 1x1 red PNG — a real decodable image.
///
/// Fixed bytes instead of `PictureRecorder`: recording a picture and encoding
/// it touch the engine's raster thread via a real-async channel that the
/// testWidgets FakeAsync zone cannot drive, so awaiting it hangs the test
/// forever ("did not complete"). Constant bytes complete synchronously.
final _png = Uint8List.fromList(const [
  137, 80, 78, 71, 13, 10, 26, 10, //
  0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222, //
  0, 0, 0, 12, 73, 68, 65, 84, 120, 156, 99, 248, 207, 192, 0, 0, 3, 1, 1, 0, 201, 254, 146, 239, //
  0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130, //
]);

Future<Uint8List> _pngBytes() async => _png;
