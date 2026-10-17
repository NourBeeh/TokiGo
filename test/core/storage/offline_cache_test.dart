import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_serializers.dart';
import 'package:tokigo/features/ai/domain/ai_response.dart';
import 'package:tokigo/features/ai/domain/ai_section.dart';
import 'package:tokigo/features/ai/domain/ai_item.dart';
import 'package:tokigo/features/ai/domain/ai_action.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';

void main() {
  group('MemoryOfflineCache - read/write operations', () {
    late MemoryOfflineCache cache;

    setUp(() {
      cache = MemoryOfflineCache();
    });

    tearDown(() async {
      await cache.clear();
    });

    test('write and read a simple map', () async {
      const key = 'test_key';
      const value = {'foo': 'bar', 'count': 42};

      await cache.write(key, value);
      final result = await cache.read(key);

      expect(result, isNotNull);
      expect(result!['foo'], equals('bar'));
      expect(result['count'], equals(42));
    });

    test('read returns null for missing key', () async {
      final result = await cache.read('nonexistent');
      expect(result, isNull);
    });

    test('contains returns true for existing key', () async {
      await cache.write('key1', {'data': 'value'});
      expect(await cache.contains('key1'), isTrue);
      expect(await cache.contains('key2'), isFalse);
    });

    test('delete removes key', () async {
      await cache.write('key1', {'data': 'value'});
      await cache.delete('key1');
      expect(await cache.contains('key1'), isFalse);
      expect(await cache.read('key1'), isNull);
    });

    test('clear removes all keys', () async {
      await cache.write('key1', {'a': 1});
      await cache.write('key2', {'b': 2});
      await cache.clear();
      expect(await cache.contains('key1'), isFalse);
      expect(await cache.contains('key2'), isFalse);
    });

    test('write overwrites existing key', () async {
      await cache.write('key1', {'version': 1});
      await cache.write('key1', {'version': 2});
      final result = await cache.read('key1');
      expect(result!['version'], equals(2));
    });
  });

  group('AI Response serialization round-trip', () {
    test('aiResponseToMap and aiResponseFromMap round-trip', () {
      final original = AiResponse(
        text: 'Found 3 flights for you',
        sections: [
          AiSection(
            id: 'section_1',
            title: 'Flights',
            subtitle: 'Available options',
            layout: HomeSectionLayout.horizontal,
            items: [
              AiItem(
                id: 'offer_1',
                type: HomeCardType.flight,
                title: 'Flight AA123',
                subtitle: 'New York → London',
                price: 599.0,
                currency: 'USD',
                actions: [
                  AiAction(type: 'openOffer', payload: {'offerId': 'offer_1'}),
                ],
              ),
            ],
            order: 1,
            metadata: {'source': 'cache_test'},
          ),
        ],
        metadata: {'query_id': 'q_123', 'model': 'gpt-4'},
      );

      final map = aiResponseToMap(original);
      final restored = aiResponseFromMap(map);

      expect(restored, isNotNull);
      expect(restored!.text, equals(original.text));
      expect(restored.sections.length, equals(original.sections.length));
      expect(restored.sections.first.title, equals(original.sections.first.title));
      expect(restored.sections.first.items.length, equals(original.sections.first.items.length));
      expect(restored.sections.first.items.first.title, equals(original.sections.first.items.first.title));
      expect(restored.sections.first.items.first.actions, isNotEmpty);
      expect(restored.metadata['query_id'], equals('q_123'));
    });

    test('aiResponseFromMap handles missing optional fields', () {
      final map = <String, dynamic>{
        'text': 'Simple response',
        'sections': [],
        'metadata': {},
      };
      final restored = aiResponseFromMap(map);
      expect(restored, isNotNull);
      expect(restored!.text, equals('Simple response'));
      expect(restored.sections, isEmpty);
    });

    test('aiResponseFromMap returns null for malformed data', () {
      final map = <String, dynamic>{
        'text': 'test',
        'sections': 'not_a_list',
        'metadata': {},
      };
      final restored = aiResponseFromMap(map);
      // Should not throw, returns null for malformed sections
      expect(restored, isNull);
    });

    test('aiSectionToMap and aiSectionFromMap round-trip', () {
      final section = AiSection(
        id: 'sec_1',
        title: 'Hotels',
        subtitle: 'Top picks',
        layout: HomeSectionLayout.grid,
        items: [
          AiItem(
            id: 'hotel_1',
            type: HomeCardType.hotel,
            title: 'Grand Hotel',
            subtitle: 'Downtown',
            rating: 4.5,
            reviewCount: 120,
          ),
        ],
        order: 2,
        metadata: {'category': 'luxury'},
      );

      final map = aiSectionToMap(section);
      final restored = aiSectionFromMap(map);

      expect(restored, isNotNull);
      expect(restored!.id, equals(section.id));
      expect(restored.title, equals(section.title));
      expect(restored.subtitle, equals(section.subtitle));
      expect(restored.layout, equals(section.layout));
      expect(restored.items.length, equals(section.items.length));
      expect(restored.order, equals(section.order));
      expect(restored.metadata['category'], equals('luxury'));
    });

    test('aiItemToMap and aiItemFromMap round-trip', () {
      final item = AiItem(
        id: 'item_1',
        type: HomeCardType.deal,
        title: 'Test Offer',
        subtitle: 'Description',
        imageUrl: 'https://example.com/img.jpg',
        price: 199.99,
        currency: 'EUR',
        rating: 4.2,
        reviewCount: 45,
        actions: [
          AiAction(type: 'openUrl', payload: {'url': 'https://example.com'}),
        ],
        metadata: {'tag': 'featured'},
      );

      final map = aiItemToMap(item);
      final restored = aiItemFromMap(map);

      expect(restored, isNotNull);
      expect(restored!.id, equals(item.id));
      expect(restored.title, equals(item.title));
      expect(restored.price, equals(item.price));
      expect(restored.currency, equals(item.currency));
      expect(restored.actions, isNotEmpty);
      expect(restored.actions.first.type, equals('openUrl'));
      expect(restored.actions.first.payload['url'], equals('https://example.com'));
    });
  });

  group('OfflineCache integration with serializers', () {
    late MemoryOfflineCache cache;

    setUp(() {
      cache = MemoryOfflineCache();
    });

    tearDown(() async {
      await cache.clear();
    });

    test('cache flight search offers', () async {
      const cacheKey = 'flight|jfk|lax|2025-06-15T00:00:00.000Z|2';
      final offersMap = {
        'offers': [
          {
            'type': 'flight',
            'id': 'f1',
            'providerId': 'p1',
            'providerName': 'Airline',
            'title': 'Flight AA123',
            'subtitle': 'JFK → LAX',
            'price': 299.0,
            'currency': 'USD',
            'availability': 'available',
            'origin': 'JFK',
            'destination': 'LAX',
            'departureTime': '2025-06-15T10:00:00.000Z',
            'arrivalTime': '2025-06-15T13:00:00.000Z',
            'airline': 'American Airlines',
            'flightNumber': 'AA123',
            'stops': 0,
            'cabinClass': 'economy',
          },
        ],
        'timestamp': DateTime.now().toIso8601String(),
      };

      await cache.write(cacheKey, offersMap);
      final cached = await cache.read(cacheKey);

      expect(cached, isNotNull);
      expect(cached!['offers'], isA<List>());
      expect((cached['offers'] as List).length, equals(1));
    });

    test('cache AI response and retrieve', () async {
      const cacheKey = 'ai|abc123def456|flights|geo|dates';
      final response = AiResponse(
        text: 'Here are your flight options',
        sections: [
          AiSection(
            title: 'Flights',
            items: [
              AiItem(
                id: '1',
                type: HomeCardType.flight,
                title: 'Flight 1',
                price: 100.0,
              ),
            ],
          ),
        ],
      );

      await cache.write(cacheKey, aiResponseToMap(response));
      final cached = await cache.read(cacheKey);

      expect(cached, isNotNull);
      final restored = aiResponseFromMap(cached!);
      expect(restored, isNotNull);
      expect(restored!.text, equals('Here are your flight options'));
    });
  });
}