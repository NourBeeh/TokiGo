import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/booking_repository.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';

/// Records the customer's explicit decision on a revalidated price/terms
/// change. The backend binds the acceptance to provider + offer + amount +
/// currency + terms version; the expected values are what the customer saw.
class DecidePriceChangeUseCase {
  final PriceChangeDecisionRepository repository;

  DecidePriceChangeUseCase(this.repository);

  Future<ApiResult<BookingRecord>> call({
    required String bookingId,
    required String decision,
    double? expectedPrice,
    String? expectedCurrency,
    String? expectedTermsVersion,
  }) {
    return repository.decidePriceChange(
      bookingId,
      decision: decision,
      expectedPrice: expectedPrice,
      expectedCurrency: expectedCurrency,
      expectedTermsVersion: expectedTermsVersion,
    );
  }
}
