import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/usecases/search_flights_usecase.dart';
import 'package:tokigo/core/repositories/contracts/flight_repository.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';

class FakeFlightRepository implements FlightRepository {
  @override
  Future<ApiResult<List<FlightOffer>>> search({
    required String origin,
    required String destination,
    required DateTime departure,
    DateTime? returnDate,
    int? passengers,
  }) async {
    return const ApiResult.success([]);
  }

  @override
  Future<ApiResult<FlightOffer>> getById(String id) async {
    return ApiResult.success(
      FlightOffer(
        id: '1',
        providerId: 'p1',
        providerName: 'P',
        title: 'T',
        description: '',
        imageUrl: '',
        price: 100,
        currency: 'USD',
        availability: true,
        validUntil: null,
        metadata: {},
        rating: 0,
        reviewCount: 0,
        origin: 'A',
        destination: 'B',
        departureTime: DateTime(2025,1,1),
        arrivalTime: DateTime(2025,1,1),
        airline: 'A',
        flightNumber: '1',
        stops: 0,
        cabinClass: 'Economy',
      ),
    );
  }
}

void main() {
  test('SearchFlightsUseCase delegates to repository', () async {
    final repo = FakeFlightRepository();
    final usecase = SearchFlightsUseCase(repo);
    final result = await usecase(
      origin: 'NYC',
      destination: 'LON',
      departure: DateTime(2025,1,10),
    );
    expect(result.isSuccess, true);
  });
}
