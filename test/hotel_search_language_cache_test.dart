import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/storage/offline_cache_serializers.dart';

void main() {
  group('hotel search cache language', () {
    final checkIn = DateTime.utc(2027, 1, 10);
    final checkOut = DateTime.utc(2027, 1, 12);

    String keyFor(String? languageCode) => hotelSearchCacheKey(
      city: 'Cairo',
      checkIn: checkIn,
      checkOut: checkOut,
      languageCode: languageCode,
    );

    test('keeps Arabic and English hotel content in separate entries', () {
      expect(keyFor('ar'), isNot(keyFor('en')));
    });

    test('the omitted language retains the English cache identity', () {
      expect(keyFor(null), keyFor('en'));
    });
  });
}
