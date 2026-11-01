import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/network/image_proxy.dart';
import 'package:tokigo/main.dart' as app;

/// Device-side performance baseline (item 1 of the 2026-10-28 plan).
///
/// The backend probe measures the server; this measures what the phone
/// actually experiences: real radio, real DNS, real TLS, real decode. It runs
/// in **profile** mode on a physical device:
///
///   flutter drive --profile -d `device-id` \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/perf_network_test.dart \
///     --dart-define=API_BASE_URL=http://`lan-ip`:3000
///
/// Numbers land in `integration_response_data.json` and on stdout. Compare
/// before/after on the same device and network — that is the only comparison
/// that means anything.
///
/// A "success" is not enough to trust a timing: a provider that fails in 20ms
/// still returns `success: true` with a non-empty `failures` list. Every
/// measurement therefore records the offer/failure counts next to the
/// milliseconds.
void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, Object?> results = <String, Object?>{};

  testWidgets('device: cold API + image latency', (WidgetTester tester) async {
    final HttpApiClient client = HttpApiClient();
    results['api_base_url'] = client.baseUrl;

    // One throwaway call so DNS/socket setup is not charged to the first
    // measurement (a cold socket is real, but it is not what we are tuning).
    await client.get<List<dynamic>>('/home/sections');

    // 1) Home feed — the response every launch pays for. It is a JSON array.
    final Stopwatch home = Stopwatch()..start();
    final homeResult = await client.get<List<dynamic>>('/home/sections');
    home.stop();
    results['home_sections_ms'] = home.elapsedMilliseconds;
    results['home_sections_ok'] = homeResult.isSuccess;
    results['home_sections_count'] = homeResult.valueOrNull?.length;

    // 2) Recommended rail — provider-backed when cold.
    final Stopwatch rail = Stopwatch()..start();
    final railResult = await client.get<Map<String, dynamic>>(
      '/home/recommended',
      queryParameters: <String, String>{'limit': '6', 'code': 'EG'},
    );
    rail.stop();
    results['recommended_ms'] = rail.elapsedMilliseconds;
    results['recommended_ok'] = railResult.isSuccess;
    results['recommended_hotels'] =
        (railResult.valueOrNull?['hotels'] as List<dynamic>?)?.length;

    // 3) Hotel search: cold (a random far-future date so no earlier run can
    //    have cached it) then warm.
    //    A provider blip is retried once on a different date so one bad minute
    //    does not poison the baseline.
    final int offsetDays = 60 + Random().nextInt(120);
    DateTime checkIn = DateTime.now().add(Duration(days: offsetDays));
    results['search_cold_date'] = _isoDay(checkIn);
    Map<String, Object?> cold = await _search(
      client,
      city: 'Cairo',
      country: 'EG',
      checkIn: checkIn,
      checkOut: checkIn.add(const Duration(days: 3)),
    );
    if (cold['ok'] != true || cold['failures'] != 0) {
      checkIn = checkIn.add(const Duration(days: 1));
      results['search_cold_retried'] = true;
      results['search_cold_date'] = _isoDay(checkIn);
      cold = await _search(
        client,
        city: 'Cairo',
        country: 'EG',
        checkIn: checkIn,
        checkOut: checkIn.add(const Duration(days: 3)),
      );
    }
    results.addAll(_prefix('search_cold', cold));

    final Map<String, Object?> warm = await _search(
      client,
      city: 'Cairo',
      country: 'EG',
      checkIn: checkIn,
      checkOut: checkIn.add(const Duration(days: 3)),
    );
    results.addAll(_prefix('search_warm', warm));

    // 4) Hotel photo: proxied (WebP) vs the provider's original, measured from
    //    this device's network.
    final String? photo = _firstImageUrl(railResult.valueOrNull);
    if (photo != null) {
      results['photo_original_url'] = photo;
      results['photo_proxied_bytes'] = await _downloadBytes(
        ImageProxy.proxied(photo, width: 640),
        results: results,
        prefix: 'photo_proxied',
      );
      results['photo_original_bytes'] = await _downloadBytes(
        photo,
        results: results,
        prefix: 'photo_original',
      );
    }

    _printResults(results);
    binding.reportData = results;
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('device: cold start to first frame', (WidgetTester tester) async {
    final Stopwatch startup = Stopwatch()..start();
    try {
      // `main` is `void` (it schedules `runApp` after the bounded cache wait),
      // so pump until the app root is actually mounted instead of awaiting it.
      app.main();
      while (startup.elapsedMilliseconds < 15000 &&
          find.byType(MaterialApp).evaluate().isEmpty) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      results['first_frame_ms'] = startup.elapsedMilliseconds;
      results['first_frame_found'] =
          find.byType(MaterialApp).evaluate().isNotEmpty;

      // Let the launch-time futures (profile / geo / Home country) finish so
      // the test does not tear the ProviderScope down underneath them — that
      // surfaces as "provider read after dispose" and fails the run.
      await Future<void>.delayed(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
    } catch (error) {
      results['first_frame_error'] = error.toString();
    }

    _printResults(results);
    binding.reportData = results;
  }, timeout: const Timeout(Duration(minutes: 3)));
}

Future<Map<String, Object?>> _search(
  HttpApiClient client, {
  required String city,
  required String country,
  required DateTime checkIn,
  required DateTime checkOut,
}) async {
  final Stopwatch watch = Stopwatch()..start();
  final result = await client.post<Map<String, dynamic>>(
    '/search/hotels',
    body: <String, Object?>{
      'city': city,
      'country': country,
      'checkIn': _isoDay(checkIn),
      'checkOut': _isoDay(checkOut),
      'guests': 2,
      'rooms': 1,
      'market': country,
    },
  );
  watch.stop();

  final Map<String, dynamic>? payload = result.valueOrNull;
  final List<dynamic> successes =
      (payload?['successes'] as List<dynamic>?) ?? const <dynamic>[];
  int offers = 0;
  for (final Object? entry in successes) {
    if (entry is Map && entry['data'] is List) {
      offers += (entry['data'] as List<dynamic>).length;
    }
  }
  return <String, Object?>{
    'ms': watch.elapsedMilliseconds,
    'ok': result.isSuccess,
    'offers': offers,
    'failures':
        (payload?['failures'] as List<dynamic>?)?.length ?? 0,
  };
}

Map<String, Object?> _prefix(String prefix, Map<String, Object?> values) {
  return values.map(
    (String key, Object? value) => MapEntry<String, Object?>('${prefix}_$key', value),
  );
}

String _isoDay(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String? _firstImageUrl(Map<String, dynamic>? payload) {
  final Object? hotels = payload?['hotels'];
  if (hotels is! List) return null;
  for (final Object? hotel in hotels) {
    if (hotel is Map && hotel['imageUrl'] is String) {
      final String url = hotel['imageUrl'] as String;
      if (url.startsWith('http')) return url;
    }
  }
  return null;
}

/// Downloads [url] and returns its byte count, recording the elapsed time
/// under `<prefix>_ms`.
Future<int?> _downloadBytes(
  String? url, {
  required Map<String, Object?> results,
  required String prefix,
}) async {
  if (url == null || url.isEmpty) return null;
  final HttpClient http = HttpClient();
  try {
    final Stopwatch watch = Stopwatch()..start();
    final HttpClientRequest request = await http.getUrl(Uri.parse(url));
    final HttpClientResponse response = await request.close();
    int bytes = 0;
    await for (final List<int> chunk in response) {
      bytes += chunk.length;
    }
    watch.stop();
    results['${prefix}_ms'] = watch.elapsedMilliseconds;
    results['${prefix}_status'] = response.statusCode;
    return bytes;
  } catch (error) {
    results['${prefix}_error'] = error.toString();
    return null;
  } finally {
    http.close(force: true);
  }
}

void _printResults(Map<String, Object?> results) {
  // Visible in `flutter drive` output, so a run is self-documenting.
  final String report = results.entries
      .map((MapEntry<String, Object?> e) => '  ${e.key}: ${e.value}')
      .join('\n');
  // ignore: avoid_print
  print('TOKIGO_PERF\n$report');
}
