import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/mappers/offer_mapper_fixed.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/flight_repository.dart';

class FlightRepositoryImpl implements FlightRepository {
  final ApiClient apiClient;

  FlightRepositoryImpl(this.apiClient);

  @override
  Future<ApiResult<List<FlightOffer>>> search({
    required String origin,
    required String destination,
    required DateTime departure,
    DateTime? returnDate,
    int? passengers,
  }) async {
    final result = await apiClient.post<Map<String, dynamic>>('/search/flights', body: {
      'origin': origin,
      'destination': destination,
      'departure': departure.toIso8601String(),
      'returnDate': returnDate?.toIso8601String(),
      'passengers': passengers,
    });

    return result.when(
      success: (data) {
        final List<dynamic> items = (data['successes'] as List?)?.expand((s) => (s['data'] as List?) ?? []).toList() ?? [];
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

  @override
  Future<ApiResult<FlightOffer>> getById(String id) async {
    return ApiResult.failure(const ApiUnknownError(message: 'getById not implemented'));
  }
}
