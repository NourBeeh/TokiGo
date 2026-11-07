// The cold-relaunch route whitelist must accept stateless pages and reject
// payload-dependent ones.

import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/storage/last_route_store.dart';

void main() {
  test('stateless destinations are restorable', () {
    for (final p in const [
      '/',
      '/flights',
      '/hotels',
      '/cars',
      '/packages',
      '/groups',
      '/bag',
      '/bag?section=likes',
      '/notifications',
      '/profile',
      '/profile/settings',
      '/wishlist',
      '/search',
      '/explore',
      '/trip-builder',
      '/admin',
    ]) {
      expect(LastRouteStore.isRestorable(p), isTrue, reason: p);
    }
  });

  test('payload-dependent or unknown destinations fall back to Home', () {
    for (final p in const [
      '/booking/review',
      '/booking/review/passengers',
      '/offer-details',
      '/bag/trip-42',
      '/city',
      '/book/confirmation',
      '/onboarding',
      '/auth',
      '/ai-chat',
      '/admin/panel',
      '',
      'not-a-path',
      '/flights/unknown',
    ]) {
      expect(LastRouteStore.isRestorable(p), isFalse, reason: p);
    }
  });
}
