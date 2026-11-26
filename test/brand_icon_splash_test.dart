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
/// the pinned wordmark (black field, white "Toki" + brand-red "Go"). Without
/// this guard a routine `dart run flutter_launcher_icons` can silently restore
/// the retired artwork. The splash keeps the in-app parasol by design.
void main() {
  const String res = 'android/app/src/main/res';

  final List<(String, String)> _pairs = <(String, String)>[
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
    (
      'drawable-xxxhdpi-v31/android12branding.png',
      'drawable-night-xxxhdpi-v31/android12branding.png',
    ),
    ('drawable/background.png', 'drawable-night/background.png'),
  ];

  Future<ui.Image> _decode(String path) async {
    final ui.Codec codec = await ui.instantiateImageCodec(
      File(path).readAsBytesSync(),
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<Uint8List> _rgba(ui.Image image) async {
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    return data!.buffer.asUint8List();
  }

  test('the icon and the splash are identical in light and dark', () async {
    for (final (String light, String night) in _pairs) {
      final ui.Image a = await _decode('$res/$light');
      final ui.Image b = await _decode('$res/$night');
      expect(a.width, b.width, reason: '$light vs $night: width');
      expect(a.height, b.height, reason: '$light vs $night: height');
      expect(
        await _rgba(a),
        await _rgba(b),
        reason:
            '$light and $night diverged — the dark assets must be fixed '
            'in BOTH appearances',
      );
    }
  });

  test(
    'the launcher icon is the wordmark (black field, white Toki, red Go)',
    () async {
      final ui.Image icon = await _decode(
        '$res/mipmap-xxxhdpi/ic_launcher.png',
      );
      final Uint8List pixels = await _rgba(icon);

      int rgbAt(int x, int y) {
        final int i = (y * icon.width + x) * 4;
        return (pixels[i] << 16) | (pixels[i + 1] << 8) | pixels[i + 2];
      }

      int countInk({required bool white, required bool leftHalf}) {
        int count = 0;
        for (int y = 0; y < icon.height; y++) {
          for (int x = 0; x < icon.width; x++) {
            if (leftHalf != x < icon.width ~/ 2) continue;
            final int i = (y * icon.width + x) * 4;
            final int r = pixels[i];
            final int g = pixels[i + 1];
            final int b = pixels[i + 2];
            if (pixels[i + 3] > 200 &&
                (white
                    ? r > 240 && g > 240 && b > 240
                    : r > 200 && g < 100 && b < 100)) {
              count++;
            }
          }
        }
        return count;
      }

      expect(rgbAt(2, 2), 0x000000, reason: 'the launcher field is not black');
      expect(
        countInk(white: true, leftHalf: true),
        greaterThan(icon.width * icon.height ~/ 100),
        reason: 'the white "Toki" is missing',
      );
      expect(
        countInk(white: false, leftHalf: false),
        greaterThan(icon.width * icon.height ~/ 100),
        reason: 'the brand-red "Go" is missing',
      );
      expect(
        countInk(white: false, leftHalf: true),
        0,
        reason: 'the "Go" half must stay on the right, like the Home wordmark',
      );
    },
  );

  test('the splash field is the dark #111111', () async {
    final ui.Image background = await _decode('$res/drawable/background.png');
    final ByteData? data = await background.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    final Uint8List pixels = data!.buffer.asUint8List();
    expect(pixels[0], 0x11, reason: 'the splash field is not #111111');
    expect(pixels[1], 0x11);
    expect(pixels[2], 0x11);
  });
}
