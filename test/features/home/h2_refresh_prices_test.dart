import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/features/home/application/home_live_validation_service.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';
/// H2 — price/availability-only refresh tests.
///
/// `refreshPrices()` must route EXCLUSIVELY through the live-validation
/// pipeline: no feed reload, no recommended-hotels reload, no image churn —
/// only the bookable products on screen get revalidated, and every existing
/// guard (one job per snapshot, content-on-screen, empty-sections no-op)
/// still applies.
void main() {
  test(
      'refreshPrices revalidates bookable products without reloading the feed',
      () async {
    final repo = _CountingRepo.withContent();
    final validation = _RecordingValidation();
    final spyController = HomeController(
      repo,
      liveValidation: _SpyValidationService(validation),
    );
    await _settle();

    final sectionsBefore = spyController.state.sections;
    expect(sectionsBefore, isNotEmpty);

    final loadCallsBefore = repo.getHomeSectionsCalls;
    final hotelsCallsBefore = repo.getRecommendedHotelsCalls;
    // Startup already ran its own post-load validation pass — measure the
    // DELTA so the assertion is about refreshPrices alone.
    final validationsBefore = validation.validateCalls;

    spyController.refreshPrices();
    await _settle();

    // The H2 refresh ran exactly ONE extra validation pass.
    expect(validation.validateCalls, validationsBefore + 1);
    // The feed and hotels were NEVER re-fetched — prices only.
    expect(repo.getHomeSectionsCalls, loadCallsBefore);
    expect(repo.getRecommendedHotelsCalls, hotelsCallsBefore);
    // Sections survive unchanged (spy validates, changes nothing).
    expect(spyController.state.sections, isNotEmpty);
  });

  test('refreshPrices is a safe no-op on the Nuitee-only empty Home',
      () async {
    final repo = _CountingRepo.empty();
    final validation = _RecordingValidation();
    final controller = HomeController(
      repo,
      liveValidation: _SpyValidationService(validation),
    );
    await _settle();

    // Nuitee-only state: empty sections (dev-preview skeleton list does not
    // count — it is not bookable content).
    controller.refreshPrices();
    await _settle();

    expect(validation.validateCalls, 0);
    expect(repo.getHomeSectionsCalls, 1); // startup load only.
  });

  test('repeated refreshPrices calls never stack validation jobs',
      () async {
    final repo = _CountingRepo.withContent();
    final validation = _RecordingValidation();
    final controller = HomeController(
      repo,
      liveValidation: _SpyValidationService(validation),
    );
    await _settle();

    final baseline = validation.validateCalls;
    controller.refreshPrices();
    controller.refreshPrices();
    controller.refreshPrices();
    await _settle();

    // The in-flight guard collapses the burst into ONE validation job.
    expect(validation.validateCalls, baseline + 1);
  });
}

Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _RecordingValidation {
  int validateCalls = 0;
}

/// Wraps the real service but records calls — proves the H2 path uses the
/// validation pipeline (not a feed reload).
class _SpyValidationService implements HomeLiveValidationService {
  _SpyValidationService(this.recorder);

  final _RecordingValidation recorder;

  @override
  Future<List<LiveValidationResult>> validate(List<HomeSection> sections) {
    recorder.validateCalls++;
    return Future.value(const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Repository double counting every fetch — the H2 contract is that these
/// counts stay UNCHANGED by refreshPrices.
class _CountingRepo implements HomeRepository {
  _CountingRepo(this._sections, this._hotels);

  _CountingRepo.withContent() : this(_contentSections(), const []);

  _CountingRepo.empty() : this(const [], const []);

  final List<HomeSection> _sections;
  final List<HomeItem> _hotels;

  int getHomeSectionsCalls = 0;
  int getRecommendedHotelsCalls = 0;

  static List<HomeSection> _contentSections() {
    return [
      HomeSection(
        id: 'live-sec',
        title: 'Live offers',
        layout: HomeSectionLayout.vertical,
        items: [
          HomeItem(
            id: 'offer-1',
            type: HomeCardType.hotel,
            title: 'Real Nuitee hotel',
            metadata: const {
              'providerId': 'nuitee',
              'providerOfferId': 'offer-1',
            },
          ),
        ],
      ),
    ];
  }

  @override
  Future<ApiResult<List<HomeSection>>> getHomeSections() async {
    getHomeSectionsCalls++;
    return ApiResult.success(_sections);
  }

  @override
  Future<ApiResult<List<HomeItem>>> getRecommendedHotels({int limit = 6}) async {
    getRecommendedHotelsCalls++;
    return ApiResult.success(_hotels);
  }

  @override
  Future<ApiResult<void>> refresh() async => const ApiResult.success(null);

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
}
