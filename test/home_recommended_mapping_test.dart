import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/impl/home_repository_impl.dart';
import 'package:tokigo/features/home/presentation/home_stay_offer.dart';

/// `/home/recommended` → [HomeItem] → the details page's [HotelOffer]
/// (regression, 2026-10-25).
///
/// The backend sends the stay's own facts at the TOP level:
///
/// ```json
/// { "id": "lp93849", "title": "Steigenberger…", "city": "Cairo",
///   "country": "EG", "checkIn": "2026-10-28", "checkOut": "2026-10-30",
///   "roomType": "Deluxe Room", "amenities": ["Pool", …],
///   "subtitle": "Cairo · 4.7★ · 4★ hotel · Free cancellation",
///   "metadata": { "providerId": "nuitee", … } }
/// ```
///
/// Two bugs are pinned here:
/// * the mapper dropped `city`, so the card fell back to the subtitle and
///   searched for a whole sentence — "No hotels found" for a stay the
///   traveller was looking at;
/// * the card opened that search instead of the hotel's own details page. The
///   details page needs where/when/how much, so the mapper must keep them —
///   and when a stay genuinely lacks a window, the builder must return null
///   (city search) rather than draw invented dates.
class _FakeClient implements ApiClient {
  _FakeClient(this._payload);

  final Map<String, dynamic> _payload;

  @override
  String get baseUrl => 'http://test.local';

  @override
  Duration get defaultTimeout => const Duration(seconds: 5);

  @override
  Map<String, String> get defaultHeaders => const <String, String>{};

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async => ApiResult<T>.success(_payload as T);

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async => throw UnimplementedError('post');

  @override
  Future<ApiResult<T>> put<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async => throw UnimplementedError('put');

  @override
  Future<ApiResult<T>> patch<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async => throw UnimplementedError('patch');

  @override
  Future<ApiResult<T>> delete<T>(
    String path, {
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async => throw UnimplementedError('delete');

  @override
  ApiResult<T> mapError<T>(Object error, {StackTrace? stackTrace}) =>
      throw UnimplementedError('mapError');
}

void main() {
  test('a recommended stay opens its own details page, not a search', () async {
    final repo = HomeRepositoryImpl(
      _FakeClient(<String, dynamic>{
        'hotels': <dynamic>[
          <String, dynamic>{
            'id': 'lp93849',
            'title': 'Steigenberger Hotel El Tahrir Cairo',
            'city': 'Cairo',
            'country': 'EG',
            'checkIn': '2026-10-28',
            'checkOut': '2026-10-30',
            'roomType': 'Deluxe Room, City View',
            'amenities': <dynamic>['Pool', 'Spa', ''],
            'subtitle': 'Cairo · 4.7★ · 4★ hotel · Free cancellation',
            'price': 423.44,
            'currency': 'USD',
            'rating': 4.7,
            'reviewCount': 15214,
            'type': 'hotel',
            'metadata': <String, dynamic>{
              'providerId': 'nuitee',
              'providerName': 'Nuitee Connect',
              'providerRateId': 'rate-1',
              'providerHotelId': 'lp93849',
              'refundable': true,
            },
          },
        ],
      }),
    );

    final List<HomeItem> items = (await repo.getRecommendedHotels()).when(
      success: (items) => items,
      failure: (error) => throw StateError('unexpected failure: $error'),
    );

    expect(items, hasLength(1));
    final HomeItem stay = items.single;
    expect(stay.title, 'Steigenberger Hotel El Tahrir Cairo');
    // The exact city, never the descriptive subtitle.
    expect(stay.metadata['city'], 'Cairo');
    // The provider's own facts survive the mapper untouched.
    expect(stay.metadata['providerId'], 'nuitee');
    expect(stay.metadata['refundable'], isTrue);

    final HotelOffer? offer = hotelOfferFromHomeStay(stay);
    expect(offer, isNotNull, reason: 'the card must open the details page');
    // The rate id, as a search result carries it — the booking provider
    // prebooks with `rateId: offerId`.
    expect(offer!.id, 'rate-1');
    expect(offer.title, 'Steigenberger Hotel El Tahrir Cairo');
    expect(offer.city, 'Cairo');
    expect(offer.country, 'EG');
    // The window is the provider's, not "today + 3".
    expect(offer.checkIn, DateTime(2026, 10, 28));
    expect(offer.checkOut, DateTime(2026, 10, 30));
    expect(offer.roomType, 'Deluxe Room, City View');
    expect(offer.amenities, <String>['Pool', 'Spa']);
    expect(offer.price, 423.44);
    expect(offer.currency, 'USD');
    expect(offer.rating, 4.7);
    // Revalidation at checkout still finds the rate it must re-price.
    expect(offer.metadata['providerRateId'], 'rate-1');
  });

  test('a stay with no window keeps no invented dates or city', () async {
    final repo = HomeRepositoryImpl(
      _FakeClient(<String, dynamic>{
        'hotels': <dynamic>[
          <String, dynamic>{
            'id': 'x-1',
            'title': 'Somewhere',
            'subtitle': 'Somewhere · 4.0★',
            'price': 100,
            'currency': 'USD',
            'metadata': <String, dynamic>{'providerId': 'nuitee'},
          },
        ],
      }),
    );

    final List<HomeItem> items = (await repo.getRecommendedHotels()).when(
      success: (items) => items,
      failure: (error) => throw StateError('unexpected failure: $error'),
    );

    expect(items.single.metadata.containsKey('city'), isFalse);
    // No city / no country / no dates → no details page. The card falls back
    // to the search it can actually run, instead of showing a fiction.
    expect(hotelOfferFromHomeStay(items.single), isNull);
  });
}
