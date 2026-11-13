import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/geo/user_location.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/network/network_status.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/features/home/domain/home_composer.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';

/// Truthful "Stays Near You" wiring (owner decision, 2026-11).
///
/// * with a valid location the rail is ranked nearest-first by real distance;
/// * without one, the backend order is preserved (the honest fallback);
/// * a stay with no coordinates is never placed as if it were close.
class _NearbyRepo implements HomeRepository {
  _NearbyRepo(this.hotels);

  final List<HomeItem> hotels;

  @override
  Future<List<HomeSection>?> readHomeSnapshot({required String audience}) async =>
      null;

  @override
  Future<void> clearHomeSnapshot({required String audience}) async {}

  @override
  Future<void> saveHomeSnapshot(
    List<HomeSection> sections, {
    required String audience,
  }) async {}

  @override
  Future<ApiResult<List<HomeSection>>> getHomeSections() async =>
      ApiResult<List<HomeSection>>.success(const <HomeSection>[]);

  @override
  Future<ApiResult<List<HomeItem>>> getRecommendedHotels({
    int limit = 6,
    String? countryCode,
    String languageCode = 'en',
    String? currency,
  }) async => ApiResult<List<HomeItem>>.success(hotels);

  @override
  Future<ApiResult<void>> refresh() async => const ApiResult<void>.success(null);

  @override
  Future<SnapshotState> snapshotState({required String audience}) async =>
      SnapshotState.unavailable;
}

HomeItem _stay(String id, {double? lat, double? lng}) {
  final Map<String, dynamic> metadata = <String, dynamic>{};
  if (lat != null) metadata['latitude'] = lat;
  if (lng != null) metadata['longitude'] = lng;
  return HomeItem(
    id: id,
    type: HomeCardType.hotel,
    title: 'Hotel $id',
    metadata: metadata,
  );
}

void main() {
  final List<HomeController> created = <HomeController>[];

  HomeController makeController(
    _NearbyRepo repo, {
    Future<UserLocation?> Function()? location,
  }) {
    final HomeController controller = HomeController(
      repo,
      audience: 'anon',
      contextBuilder: (_) async => const HomeCompositionContext(
        userState: HomeUserState.freshAnonymous,
      ),
      liveValidation: null,
      countryCode: null,
      languageCode: null,
      currencyCode: null,
      location: location,
    );
    created.add(controller);
    return controller;
  }

  tearDown(() {
    for (final HomeController controller in created.reversed) {
      controller.dispose();
    }
    created.clear();
    NetworkStatus.instance.reportOnline();
  });

  test('with a valid location the rail ranks nearest-first', () async {
    final HomeController controller = makeController(
      _NearbyRepo(<HomeItem>[
        _stay('far', lat: 10, lng: 10),
        _stay('near', lat: 0.1, lng: 0.1),
        _stay('mid', lat: 1, lng: 1),
      ]),
      location: () async => const UserLocation(latitude: 0, longitude: 0),
    );

    await controller.loadRecommendedHotels();

    expect(
      controller.state.recommendedHotels
          .map((HomeItem h) => h.id)
          .toList(),
      <String>['near', 'mid', 'far'],
    );
  });

  test('without a location the backend order is preserved', () async {
    final HomeController controller = makeController(
      _NearbyRepo(<HomeItem>[
        _stay('far', lat: 10, lng: 10),
        _stay('near', lat: 0.1, lng: 0.1),
      ]),
    );

    await controller.loadRecommendedHotels();

    expect(
      controller.state.recommendedHotels
          .map((HomeItem h) => h.id)
          .toList(),
      <String>['far', 'near'],
    );
  });

  test('a stay with no coordinates sorts after the located ones', () async {
    final HomeController controller = makeController(
      _NearbyRepo(<HomeItem>[
        _stay('unknown'),
        _stay('near', lat: 0.1, lng: 0.1),
      ]),
      location: () async => const UserLocation(latitude: 0, longitude: 0),
    );

    await controller.loadRecommendedHotels();

    expect(
      controller.state.recommendedHotels
          .map((HomeItem h) => h.id)
          .toList(),
      <String>['near', 'unknown'],
    );
  });
}
