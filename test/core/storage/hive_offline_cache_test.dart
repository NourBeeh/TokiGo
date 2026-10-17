import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/storage/hive_offline_cache.dart';

void main() {
  group('HiveOfflineCache.convertHiveValue', () {
    test(
      'regression: a disk-round-tripped Map<dynamic, dynamic> is deep-converted '
      'to Map<String, dynamic> on every level',
      () {
        // This is exactly what Hive returns after reading an entry back from
        // disk — generic type arguments are lost in binary serialization.
        final Object raw = <dynamic, dynamic>{
          'text': 'Hello',
          'sections': [
            <dynamic, dynamic>{
              'type': 'flight_offer',
              'payload': <dynamic, dynamic>{'price': 120.5, 'nested': true},
              'tags': ['cheap', 'direct'],
            },
          ],
        };

        final result = HiveOfflineCache.convertHiveValue(raw);

        expect(result, isNotNull);
        expect(result, isA<Map<String, dynamic>>());
        final sections = result!['sections'] as List<dynamic>;
        final section = sections.first as Map<String, dynamic>;
        final payload = section['payload'] as Map<String, dynamic>;
        expect(payload['price'], 120.5);
        expect((section['tags'] as List).first, 'cheap');
      },
    );

    test('converts non-string keys with toString()', () {
      final result = HiveOfflineCache.convertHiveValue({
        42: 'answer',
      });
      expect(result, isA<Map<String, dynamic>>());
      expect(result!['42'], 'answer');
    });

    test('returns null for non-map input', () {
      expect(HiveOfflineCache.convertHiveValue(null), isNull);
      expect(HiveOfflineCache.convertHiveValue('string'), isNull);
      expect(HiveOfflineCache.convertHiveValue(123), isNull);
      expect(HiveOfflineCache.convertHiveValue(['list']), isNull);
    });

    test('preserves primitive values untouched', () {
      final result = HiveOfflineCache.convertHiveValue({
        'int': 1,
        'double': 1.5,
        'bool': false,
        'null': null,
        'string': 'text',
      });
      expect(result, {
        'int': 1,
        'double': 1.5,
        'bool': false,
        'null': null,
        'string': 'text',
      });
    });
  });
}
