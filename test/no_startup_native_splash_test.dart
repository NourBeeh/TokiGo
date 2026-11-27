import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the two launch-path decisions the owner asked for explicitly:
/// the app opens straight into Home (no startup/onboarding screen), and every
/// native splash layer renders one fixed dark wordmark with no legacy layer.
void main() {
  test('the router has no startup or onboarding gate', () {
    final String router = File(
      'lib/app/router/go_router_config.dart',
    ).readAsStringSync();

    expect(router, isNot(contains("path: '/onboarding'")));
    expect(router, isNot(contains("return '/onboarding'")));
    expect(router, isNot(contains('onboardingProvider')));
  });

  test(
    'Android 12 uses one splash wordmark, not a duplicate branding layer',
    () {
      for (final String path in <String>[
        'android/app/src/main/res/values-v31/styles.xml',
        'android/app/src/main/res/values-night-v31/styles.xml',
      ]) {
        final String styles = File(path).readAsStringSync();
        expect(
          styles,
          isNot(contains('windowSplashScreenBrandingImage')),
          reason: path,
        );
        expect(
          styles,
          contains('windowSplashScreenAnimatedIcon'),
          reason: path,
        );
      }

      final String pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('    branding:')));
      expect(pubspec, isNot(contains('    branding_dark:')));
    },
  );

  test(
    'the iOS launch screen uses the fixed dark field and a fitting mark',
    () {
      final String storyboard = File(
        'ios/Runner/Base.lproj/LaunchScreen.storyboard',
      ).readAsStringSync();

      expect(storyboard, contains('contentMode="scaleAspectFit"'));
      expect(storyboard, isNot(contains('red="1" green="1" blue="1"')));
      expect(storyboard, contains('red="0.066666666669999999"'));
    },
  );
}
