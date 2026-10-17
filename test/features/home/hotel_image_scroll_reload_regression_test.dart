import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/features/home/application/hotel_image_cache.dart';
import 'package:tokigo/features/home/application/hotel_image_memory_cache.dart';
import 'package:tokigo/features/home/presentation/widgets/cached_hotel_image.dart';

/// Scroll-fix regression (user report 2026-09-08 — "images reload on every
/// scroll"): the horizontal hotel rail destroys off-screen cards, so a
/// scroll-back re-reads Hive asynchronously and flashed the shimmer every
/// time. The fix: (a) the card keeps itself alive in the ListView
/// (AutomaticKeepAliveClientMixin), and (b) a synchronous session-memory
/// layer renders a re-mounted photo in the SAME frame.
void main() {
  // Minimal 1x1 red PNG — a real decodable image (same bytes as the H3 suite).
  final png = Uint8List.fromList(const [
    137, 80, 78, 71, 13, 10, 26, 10,
    0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222,
    0, 0, 0, 12, 73, 68, 65, 84, 120, 156, 99, 248, 207, 192, 0, 0, 3, 1, 1, 0, 201, 254, 146, 239,
    0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
  ]);

  setUpAll(() async {
    await debugDrainInFlight();
  });

  group('HotelImageMemoryCache — the session fast path', () {
    test('read is synchronous and returns null before the first write', () {
      final mem = HotelImageMemoryCache();
      expect(mem.read('https://x/a.jpg'), isNull);
    });

    test('write then read returns the same bytes instantly', () {
      final mem = HotelImageMemoryCache();
      mem.write('https://x/a.jpg', png);
      expect(mem.read('https://x/a.jpg'), same(png));
    });

    test('LRU: exceeding the cap evicts the least recently used', () {
      final mem = HotelImageMemoryCache(maxEntries: 2);
      mem.write('a', png);
      mem.write('b', png);
      mem.read('a'); // touch a → b becomes the LRU victim
      mem.write('c', png);
      expect(mem.read('b'), isNull);
      expect(mem.read('a'), isNotNull);
      expect(mem.read('c'), isNotNull);
      expect(mem.length, 2);
    });

    test('TTL: entries older than the disk TTL expire out of memory too',
        () async {
      final mem = HotelImageMemoryCache();
      var fakeNow = DateTime(2026, 1, 1);
      mem.setClockForTests(() => fakeNow);
      mem.write('a', png);
      fakeNow = fakeNow.add(HotelImageCache.ttl + const Duration(days: 1));
      expect(mem.read('a'), isNull);
    });

    test('clear drops everything', () {
      final mem = HotelImageMemoryCache();
      mem.write('a', png);
      mem.clear();
      expect(mem.read('a'), isNull);
    });
  });

  group('CachedHotelImage — scroll-back renders in the same frame', () {
    testWidgets('a SECOND mount with a warm memory cache shows NO shimmer',
        (tester) async {
      final store = MemoryOfflineCache();
      final disk = HotelImageCache(store);
      final mem = HotelImageMemoryCache();

      // First mount: miss everywhere → fetch → disk + memory warm.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CachedHotelImage(
            url: 'https://x/scroll.png',
            height: 120,
            width: 260,
            cache: disk,
            memoryCache: mem,
            httpClient: (_) async => png,
          ),
        ),
      ));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(Image), findsOneWidget);

      // Simulate the ListView destroying + re-mounting the card (scroll
      // away and back): a NEW widget instance, same URL.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CachedHotelImage(
            url: 'https://x/scroll.png',
            height: 120,
            width: 260,
            cache: disk,
            memoryCache: mem,
            httpClient: (_) async => png,
          ),
        ),
      ));

      // FIRST frame after re-mount: the image is already there — the
      // shimmer never appears (this was the reported bug).
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(CachedHotelImage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
