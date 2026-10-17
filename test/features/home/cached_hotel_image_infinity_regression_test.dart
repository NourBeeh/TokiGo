import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/features/home/application/hotel_image_cache.dart';
import 'package:tokigo/features/home/presentation/widgets/cached_hotel_image.dart';

/// Regression (user bug 2026-09-08): the Home hotel card passes
/// `width: double.infinity` so the photo fills the 260px card width. Once
/// cached bytes arrive, the decode path computed `(infinity * dpr).round()`
/// → "Unsupported operation: Infinity or NaN toInt" → the red ErrorWidget
/// rendered inside the card → "BOTTOM OVERFLOWED BY ~99k PIXELS".
///
/// The fix: callers keep `width: double.infinity` (fill behavior is
/// correct); the widget resolves the DECODE width from the layout
/// constraints instead of multiplying the raw width.
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

  testWidgets(
    'decode path survives width: double.infinity (the Home rail call)',
    (tester) async {
      final store = MemoryOfflineCache();
      final cache = HotelImageCache(store);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 260, // the real card width
                child: CachedHotelImage(
                  url: 'https://x/inf.png',
                  height: 120,
                  width: double.infinity,
                  cache: cache,
                  httpClient: (_) async => png,
                ),
              ),
            ),
          ),
        ),
      );

      // Let the async load land (shimmer pulses forever, so no settle).
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // The bug threw "Infinity or NaN toInt" right here and rendered the
      // red error box instead of the image.
      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<ResizeImage>());
      // Decode width must be finite (from layout constraints, not infinity).
      final decodeWidth = (image.image as ResizeImage).width;
      expect(decodeWidth, isNotNull);
      expect(decodeWidth! < 10000, isTrue, reason: 'decode width must be finite');
      expect(decodeWidth, greaterThan(0));
    },
  );

  testWidgets('finite width still decodes at the expected resolution', (tester) async {
    final store = MemoryOfflineCache();
    final cache = HotelImageCache(store);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CachedHotelImage(
              url: 'https://x/finite.png',
              height: 120,
              width: 260,
              cache: cache,
              httpClient: (_) async => png,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as ResizeImage).width, greaterThan(0));
  });
}
