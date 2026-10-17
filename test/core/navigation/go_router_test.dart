import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import 'package:tokigo/app/router/go_router_config.dart';

void main() {
  setUpAll(() {
    // The router watches onboardingProvider, whose controller opens a Hive
    // settings box — give it a home in the test sandbox.
    Hive.init(Directory.systemTemp.createTempSync('wt_router_test').path);
  });

  test('GoRouter provider builds without error', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(goRouterProvider);
    expect(router, isA<GoRouter>());
  });
}
