import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/navigation/app_route.dart';

void main() {
  test('paths are distinct and start with /', () {
    final paths = AppRoute.values.map((r) => r.path).toSet();
    expect(paths.length, AppRoute.values.length);
    expect(paths.every((p) => p.startsWith('/')), isTrue);
  });

  test('primaryDestinations contains the floating-nav entries', () {
    expect(AppRoute.primaryDestinations, containsAll([AppRoute.home, AppRoute.settings]));
  });

  test('icons differ from outlined vs filled', () {
    expect(AppRoute.home.iconFor(selected: false), AppRoute.home.outlinedIcon);
    expect(AppRoute.home.iconFor(selected: true), AppRoute.home.filledIcon);
  });
}