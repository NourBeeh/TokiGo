import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/search/flight_search_params.dart';
import 'package:tokigo/core/mappers/offer_mapper_fixed.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/flight_repository.dart';

class FlightRepositoryImpl implements FlightRepository {
  final ApiClient apiClient;
  String? _nextMarket;
  String? _nextCurrency;

  FlightRepositoryImpl(this.apiClient);

  void setNextSearchContext({String? market, String? currency}) {
    _nextMarket = market;
    _nextCurrency = currency;
  }

  @override
  Future<ApiResult<List<FlightOffer>>> search({
    required String origin,
    required String destination,
    required DateTime departure,
    DateTime? returnDate,
    int? passengers,
    int? children,
    int? infants,
    List<int>? childAges,
    List<int>? infantAges,
    List<FlightSearchLeg>? legs,
    String? cabinClass,
    bool? directOnly,
  }) async {
    final result = await apiClient.post<Map<String, dynamic>>(
      '/search/flights',
      body: buildSearchBody(
        origin: origin,
        destination: destination,
        departure: departure,
        returnDate: returnDate,
        passengers: passengers,
        children: children,
        infants: infants,
        childAges: childAges,
        infantAges: infantAges,
        legs: legs,
        market: _nextMarket,
        currency: _nextCurrency,
        cabinClass: cabinClass,
        directOnly: directOnly,
      ),
    );

    return result.when(
      success: (data) {
        final List<dynamic> items =
            (data['successes'] as List?)
                ?.expand((s) => (s['data'] as List?) ?? [])
                .toList() ??
            [];
        final offers = <FlightOffer>[];
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final offer = mapOffer(item) as FlightOffer?;
            if (offer != null) offers.add(offer);
          }
        }
        return ApiResult.success(offers);
      },
      failure: (error) => ApiResult.failure(error),
    );
  }

  static Map<String, dynamic> buildSearchBody({
    required String origin,
    required String destination,
    required DateTime departure,
    DateTime? returnDate,
    int? passengers,
    int? children,
    int? infants,
    List<int>? childAges,
    List<int>? infantAges,
    List<FlightSearchLeg>? legs,
    String? market,
    String? currency,
    String? cabinClass,
    bool? directOnly,
  }) => <String, dynamic>{
    'origin': origin,
    'destination': destination,
    'departure': departure.toIso8601String(),
    'returnDate': returnDate?.toIso8601String(),
    // `passengers` is the adult count on this endpoint: the backend's
    // `FlightSearchDto` has no `adults` field (an undeclared field would be
    // rejected by `forbidNonWhitelisted`), and both flight providers fall back
    // to `passengers` for the adult count.
    'passengers': passengers,
    'children': ?children,
    'infants': ?infants,
    if (childAges != null && childAges.isNotEmpty) 'childAges': childAges,
    if (infantAges != null && infantAges.isNotEmpty) 'infantAges': infantAges,
    if (legs != null && legs.isNotEmpty)
      'legs': <Map<String, String>>[
        for (final FlightSearchLeg leg in legs)
          <String, String>{
            'origin': leg.origin,
            'destination': leg.destination,
            'date': leg.date.toIso8601String(),
          },
      ],
    if (market != null && market.isNotEmpty) 'market': market,
    if (currency != null && currency.isNotEmpty) 'currency': currency,
    if (cabinClass != null && cabinClass.isNotEmpty) 'cabinClass': cabinClass,
    if (directOnly != null && directOnly) 'directOnly': true,
  };

  @override
  Future<ApiResult<FlightOffer>> getById(String id) async {
    return ApiResult.failure(
      const ApiUnknownError(message: 'getById not implemented'),
    );
  }
}
