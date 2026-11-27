import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Pins the launcher icon and the launch splash to the DARK artwork in BOTH
/// appearances — owner decision (2026-11): "اعمل الأيقونة والسبلاش الداكنين
/// ثابتين في كل الأوضاع".
///
/// The light (`mipmap-*`, `drawable-*`) and night (`mipmap-night-*`,
/// `drawable-night-*`) resources must be pixel-identical, and the mark must be
/// the pinned wordmark (black field, white TokiGo, no red "Go"). Without this
/// guard a routine `dart run flutter_launcher_icons` can silently restore the
/// retired artwork. Since 2026-11-27 the splash shows the white wordmark only:
/// the parasol and the red "Go" are gone from every launch asset.
void main() {
  const String res = 'android/app/src/main/res';

  final List<(String, String)> pairs = <(String, String)>[
    ('mipmap-xxxhdpi/ic_launcher.png', 'mipmap-night-xxxhdpi/ic_launcher.png'),
    (
      'drawable-xxxhdpi/ic_launcher_foreground.png',
      'drawable-night-xxxhdpi/ic_launcher_foreground.png',
    ),
    ('drawable-xxxhdpi/splash.png', 'drawable-night-xxxhdpi/splash.png'),
    (
      'drawable-xxxhdpi/android12splash.png',
      'drawable-night-xxxhdpi/android12splash.png',
    ),
    ('drawable/background.png', 'drawable-night/background.png'),
  ];

  Future<ui.Image> decodeImage(String path) async {
    final ui.Codec codec = await ui.instantiateImageCodec(
      File(path).readAsBytesSync(),
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<Uint8List> rgbaBytes(ui.Image image) async {
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    return data!.buffer.asUint8List();
  }

  test('the icon and the splash are identical in light and dark', () async {
    for (final (String light, String night) in pairs) {
      final ui.Image a = await decodeImage('$res/$light');
      final ui.Image b = await decodeImage('$res/$night');
      expect(a.width, b.width, reason: '$light vs $night: width');
      expect(a.height, b.height, reason: '$light vs $night: height');
      expect(
        await rgbaBytes(a),
        await rgbaBytes(b),
        reason:
            '$light and $night diverged — the dark assets must be fixed '
            'in BOTH appearances',
      );
    }
  });

  test(
    'the launcher icon is the all-white wordmark (no brand-red Go)',
    () async {
      final ui.Image icon = await decodeImage(
        '$res/mipmap-xxxhdpi/ic_launcher.png',
      );
      final Uint8List pixels = await rgbaBytes(icon);

      int rgbAt(int x, int y) {
        final int i = (y * icon.width + x) * 4;
        return (pixels[i] << 16) | (pixels[i + 1] << 8) | pixels[i + 2];
      }

      int countWhite({required bool leftHalf}) {
        int count = 0;
        for (int y = 0; y < icon.height; y++) {
          for (int x = 0; x < icon.width; x++) {
            if (leftHalf != x < icon.width ~/ 2) continue;
            final int i = (y * icon.width + x) * 4;
            if (pixels[i + 3] > 200 &&
                pixels[i] > 240 &&
                pixels[i + 1] > 240 &&
                pixels[i + 2] > 240) {
              count++;
            }
          }
        }
        return count;
      }

      int countRed() {
        int count = 0;
        for (int i = 0; i < pixels.length; i += 4) {
          if (pixels[i + 3] > 200 &&
              pixels[i] > 200 &&
              pixels[i + 1] < 100 &&
              pixels[i + 2] < 100) {
            count++;
          }
        }
        return count;
      }

      expect(rgbAt(2, 2), 0x000000, reason: 'the launcher field is not black');
      expect(
        countWhite(leftHalf: true),
        greaterThan(icon.width * icon.height ~/ 100),
        reason: 'the white "Toki" is missing',
      );
      expect(
        countWhite(leftHalf: false),
        greaterThan(icon.width * icon.height ~/ 100),
        reason: 'the white "Go" is missing',
      );
      expect(
        countRed(),
        0,
        reason: 'the launcher icon must not keep the Home header\'s red "Go"',
      );
    },
  );

  test('Android 12 has one splash layer, no duplicate branding raster', () {
    expect(
      File('$res/drawable-xxxhdpi-v31/android12branding.png').existsSync(),
      isFalse,
      reason: 'the second wordmark under the splash icon was removed',
    );
  });

  test('the splash field is the dark #111111', () async {
    final ui.Image background = await decodeImage(
      '$res/drawable/background.png',
    );
    final ByteData? data = await background.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    final Uint8List pixels = data!.buffer.asUint8List();
    expect(pixels[0], 0x11, reason: 'the splash field is not #111111');
    expect(pixels[1], 0x11);
    expect(pixels[2], 0x11);
  });

  test('the launch artwork is white TokiGo with no red Go', () async {
    for (final String path in <String>[
      '$res/drawable-xxxhdpi/splash.png',
      '$res/drawable-xxxhdpi/android12splash.png',
    ]) {
      final ui.Image image = await decodeImage(path);
      final Uint8List pixels = await rgbaBytes(image);
      int white = 0;
      int red = 0;
      for (int i = 0; i < pixels.length; i += 4) {
        if (pixels[i + 3] <= 200) continue;
        if (pixels[i] > 240 && pixels[i + 1] > 240 && pixels[i + 2] > 240) {
          white++;
        }
        if (pixels[i] > 200 && pixels[i + 1] < 100 && pixels[i + 2] < 100) {
          red++;
        }
      }
      expect(
        white,
        greaterThan(500),
        reason: '$path must show the white wordmark',
      );
      expect(red, 0, reason: '$path still carries the retired red Go');
    }
  });
}
