import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/ai/domain/ai_home_mapper.dart';
import 'package:tokigo/features/ai/domain/ai_item.dart';
import 'package:tokigo/features/ai/domain/ai_parsing.dart';
import 'package:tokigo/features/ai/domain/ai_response.dart';
import 'package:tokigo/features/ai/domain/ai_section.dart';

/// Phase 10A-F — Flutter-side AI parsing hardening.
///
/// Exercises `AiResponse.fromMap` / `AiSection.fromMap` / `AiItem.fromMap`
/// directly (not through widgets) against the payload shapes a normalized
/// backend is *not* supposed to send: missing keys, explicit nulls, wrong
/// types, unknown enum values and partially-populated objects.
///
/// Every case asserts on the degraded value, and the wrong-type cases assert
/// `returnsNormally` because these fields previously used `as List?` casts
/// that raised a `TypeError`.
void main() {
  group('AiResponse.fromMap — sections field', () {
    test('parses a fully valid response', () {
      final payload = <String, dynamic>{
        'text': 'Found 2 hotels',
        'metadata': <String, dynamic>{'queryId': 'q1'},
        'sections': <Object?>[
          <String, dynamic>{
            'id': 's1',
            'title': 'Hotels',
            'subtitle': 'Best match',
            'layout': 'horizontalPeek',
            'order': 1,
            'items': <Object?>[
              <String, dynamic>{
                'id': 'h1',
                'type': 'hotel',
                'title': 'Grand Palm',
                'price': 320,
                'currency': 'USD',
                'rating': 4.6,
                'reviewCount': 214,
                'highlights': <String>['Pool'],
                'tags': <String>['4-star'],
                'order': 2,
                'data': <String, dynamic>{'city': 'Paris'},
                'actions': <Object?>[
                  <String, dynamic>{
                    'type': 'book',
                    'label': 'Book',
                    'payload': <String, dynamic>{'offerId': 'h1'},
                  },
                ],
              },
            ],
          },
        ],
      };

      final response = AiResponse.fromMap(payload);

      expect(response.text, 'Found 2 hotels');
      expect(response.metadata['queryId'], 'q1');
      expect(response.sections, hasLength(1));

      final section = response.sections.single;
      expect(section.id, 's1');
      expect(section.title, 'Hotels');
      expect(section.subtitle, 'Best match');
      expect(section.layout, HomeSectionLayout.horizontalPeek);
      expect(section.order, 1);
      expect(section.items, hasLength(1));

      final item = section.items.single;
      expect(item.id, 'h1');
      expect(item.type, HomeCardType.hotel);
      expect(item.title, 'Grand Palm');
      expect(item.price, 320.0);
      expect(item.currency, 'USD');
      expect(item.rating, 4.6);
      expect(item.reviewCount, 214);
      expect(item.highlights, <String>['Pool']);
      expect(item.tags, <String>['4-star']);
      expect(item.order, 2);
      expect(item.data['city'], 'Paris');
      expect(item.actions, hasLength(1));
      expect(item.actions.single.type, 'book');
      expect(item.actions.single.label, 'Book');
      expect(item.actions.single.payload['offerId'], 'h1');
    });

    test('missing sections key degrades to an empty list', () {
      final response = AiResponse.fromMap(<String, dynamic>{'text': 'hi'});

      expect(response.sections, isEmpty);
      expect(response.text, 'hi');
    });

    test('sections: null degrades to an empty list', () {
      final response =
          AiResponse.fromMap(<String, dynamic>{'sections': null});

      expect(response.sections, isEmpty);
    });

    test('sections as String does not throw and degrades', () {
      expect(
        () => AiResponse.fromMap(<String, dynamic>{'sections': 'not-a-list'}),
        returnsNormally,
      );
      expect(
        AiResponse.fromMap(<String, dynamic>{'sections': 'not-a-list'}).sections,
        isEmpty,
      );
    });

    test('sections as num / bool / Map does not throw and degrades', () {
      for (final wrong in <Object?>[42, 3.5, true, <String, dynamic>{'a': 1}]) {
        expect(
          () => AiResponse.fromMap(<String, dynamic>{'sections': wrong}),
          returnsNormally,
          reason: 'sections: $wrong must not raise',
        );
        expect(
          AiResponse.fromMap(<String, dynamic>{'sections': wrong}).sections,
          isEmpty,
          reason: 'sections: $wrong must degrade to []',
        );
      }
    });

    test('non-map entries inside sections are skipped, valid ones kept', () {
      final response = AiResponse.fromMap(<String, dynamic>{
        'sections': <Object?>[
          null,
          'garbage',
          42,
          <String, dynamic>{'title': 'Kept'},
        ],
      });

      expect(response.sections, hasLength(1));
      expect(response.sections.single.title, 'Kept');
    });

    test('metadata wrong type degrades to an empty map', () {
      expect(
        AiResponse.fromMap(<String, dynamic>{'metadata': 'nope'}).metadata,
        isEmpty,
      );
      expect(
        AiResponse.fromMap(<String, dynamic>{'metadata': null}).metadata,
        isEmpty,
      );
    });

    test('falls back from text to content', () {
      expect(
        AiResponse.fromMap(<String, dynamic>{'content': 'from-content'}).text,
        'from-content',
      );
      expect(
        AiResponse.fromMap(
          <String, dynamic>{'text': null, 'content': 'from-content'},
        ).text,
        'from-content',
      );
    });
  });

  group('AiSection.fromMap — items field', () {
    test('missing items key degrades to an empty list', () {
      final section = AiSection.fromMap(<String, dynamic>{'title': 'S'});

      expect(section.items, isEmpty);
      expect(section.title, 'S');
    });

    test('items: null degrades to an empty list', () {
      final section =
          AiSection.fromMap(<String, dynamic>{'title': 'S', 'items': null});

      expect(section.items, isEmpty);
    });

    test('items as String does not throw and degrades', () {
      expect(
        () => AiSection.fromMap(<String, dynamic>{'items': 'nope'}),
        returnsNormally,
      );
      expect(
        AiSection.fromMap(<String, dynamic>{'items': 'nope'}).items,
        isEmpty,
      );
    });

    test('items as num / bool / Map does not throw and degrades', () {
      for (final wrong in <Object?>[7, true, <String, dynamic>{'a': 1}]) {
        expect(
          () => AiSection.fromMap(<String, dynamic>{'items': wrong}),
          returnsNormally,
          reason: 'items: $wrong must not raise',
        );
        expect(
          AiSection.fromMap(<String, dynamic>{'items': wrong}).items,
          isEmpty,
        );
      }
    });

    test('non-map entries inside items are skipped, valid ones kept', () {
      final section = AiSection.fromMap(<String, dynamic>{
        'title': 'S',
        'items': <Object?>[
          null,
          'garbage',
          <String, dynamic>{'id': 'k', 'type': 'flight', 'title': 'Kept'},
        ],
      });

      expect(section.items, hasLength(1));
      expect(section.items.single.id, 'k');
    });

    test('missing title degrades to an empty string', () {
      expect(AiSection.fromMap(const <String, dynamic>{}).title, '');
    });
  });

  group('AiItem.fromMap — highlights and tags', () {
    test('missing highlights and tags degrade to empty lists', () {
      final item = AiItem.fromMap(<String, dynamic>{'id': 'i', 'title': 'T'});

      expect(item.highlights, isEmpty);
      expect(item.tags, isEmpty);
    });

    test('highlights: null and tags: null degrade to empty lists', () {
      final item = AiItem.fromMap(
        <String, dynamic>{'highlights': null, 'tags': null},
      );

      expect(item.highlights, isEmpty);
      expect(item.tags, isEmpty);
    });

    test('highlights as String does not throw and degrades', () {
      expect(
        () => AiItem.fromMap(<String, dynamic>{'highlights': 'Pool'}),
        returnsNormally,
      );
      expect(
        AiItem.fromMap(<String, dynamic>{'highlights': 'Pool'}).highlights,
        isEmpty,
      );
    });

    test('tags as num / bool / Map does not throw and degrades', () {
      for (final wrong in <Object?>[5, true, <String, dynamic>{'a': 1}]) {
        expect(
          () => AiItem.fromMap(<String, dynamic>{'tags': wrong}),
          returnsNormally,
          reason: 'tags: $wrong must not raise',
        );
        expect(AiItem.fromMap(<String, dynamic>{'tags': wrong}).tags, isEmpty);
      }
    });

    test('mixed-type list elements are stringified and nulls dropped', () {
      final item = AiItem.fromMap(<String, dynamic>{
        'highlights': <Object?>['Pool', 1, null, true],
        'tags': <Object?>[null, null],
      });

      expect(item.highlights, <String>['Pool', '1', 'true']);
      expect(item.tags, isEmpty);
    });

    test('data / metadata wrong types degrade to empty maps', () {
      final item = AiItem.fromMap(
        <String, dynamic>{'data': 'nope', 'metadata': 42},
      );

      expect(item.data, isEmpty);
      expect(item.metadata, isEmpty);
    });
  });

  group('unknown and wrong-typed enum values', () {
    test('unknown layout falls back to vertical', () {
      expect(
        AiSection.fromMap(<String, dynamic>{'layout': 'diagonal'}).layout,
        HomeSectionLayout.vertical,
      );
    });

    test('missing and null layout fall back to vertical', () {
      expect(
        AiSection.fromMap(const <String, dynamic>{}).layout,
        HomeSectionLayout.vertical,
      );
      expect(
        AiSection.fromMap(<String, dynamic>{'layout': null}).layout,
        HomeSectionLayout.vertical,
      );
    });

    test('wrong-typed layout falls back to vertical without throwing', () {
      for (final wrong in <Object?>[42, true, <String, dynamic>{'a': 1}]) {
        expect(
          () => AiSection.fromMap(<String, dynamic>{'layout': wrong}),
          returnsNormally,
        );
        expect(
          AiSection.fromMap(<String, dynamic>{'layout': wrong}).layout,
          HomeSectionLayout.vertical,
        );
      }
    });

    test('layout matching is case-insensitive', () {
      expect(
        AiSection.fromMap(<String, dynamic>{'layout': 'HorizontalPeek'}).layout,
        HomeSectionLayout.horizontalPeek,
      );
      expect(
        AiSection.fromMap(<String, dynamic>{'layout': 'GRID'}).layout,
        HomeSectionLayout.grid,
      );
    });

    test('unknown card type falls back to deal', () {
      expect(
        AiItem.fromMap(<String, dynamic>{'type': 'submarine'}).type,
        HomeCardType.deal,
      );
    });

    test('missing, null and wrong-typed card type fall back to deal', () {
      expect(AiItem.fromMap(const <String, dynamic>{}).type, HomeCardType.deal);
      for (final wrong in <Object?>[null, 42, true, <String, dynamic>{'a': 1}]) {
        expect(
          () => AiItem.fromMap(<String, dynamic>{'type': wrong}),
          returnsNormally,
        );
        expect(
          AiItem.fromMap(<String, dynamic>{'type': wrong}).type,
          HomeCardType.deal,
        );
      }
    });
  });

  group('partial responses', () {
    test('text only', () {
      final response = AiResponse.fromMap(<String, dynamic>{'text': 'only'});

      expect(response.text, 'only');
      expect(response.sections, isEmpty);
      expect(response.metadata, isEmpty);
    });

    test('sections only, no text', () {
      final response = AiResponse.fromMap(<String, dynamic>{
        'sections': <Object?>[
          <String, dynamic>{'title': 'S', 'items': <Object?>[]},
        ],
      });

      expect(response.text, isNull);
      expect(response.sections, hasLength(1));
      expect(response.sections.single.items, isEmpty);
    });

    test('completely empty payload', () {
      final response = AiResponse.fromMap(const <String, dynamic>{});

      expect(response.text, isNull);
      expect(response.sections, isEmpty);
      expect(response.metadata, isEmpty);
    });

    test('empty section and empty item objects', () {
      final response = AiResponse.fromMap(<String, dynamic>{
        'sections': <Object?>[
          <String, dynamic>{
            'items': <Object?>[const <String, dynamic>{}],
          },
        ],
      });

      final section = response.sections.single;
      expect(section.title, '');
      expect(section.id, isNull);
      expect(section.order, isNull);

      final item = section.items.single;
      expect(item.id, '');
      expect(item.title, '');
      expect(item.type, HomeCardType.deal);
      expect(item.price, isNull);
      expect(item.rating, isNull);
      expect(item.reviewCount, isNull);
    });
  });

  group('numeric coercion helpers', () {
    test('asInt accepts int, double and numeric String', () {
      expect(asInt(3), 3);
      expect(asInt(1.0), 1);
      expect(asInt('4'), 4);
      expect(asInt(' 5 '), 5);
    });

    test('asInt rejects non-numeric and non-finite values', () {
      expect(asInt(null), isNull);
      expect(asInt('abc'), isNull);
      expect(asInt(true), isNull);
      expect(asInt(<String, dynamic>{'a': 1}), isNull);
      expect(asInt(double.nan), isNull);
      expect(asInt(double.infinity), isNull);
    });

    test('asDouble accepts num and numeric String', () {
      expect(asDouble(235), 235.0);
      expect(asDouble(4.8), 4.8);
      expect(asDouble('4.8'), 4.8);
    });

    test('asDouble rejects non-numeric and non-finite values', () {
      expect(asDouble(null), isNull);
      expect(asDouble('abc'), isNull);
      expect(asDouble(<String, dynamic>{'a': 1}), isNull);
      expect(asDouble(double.nan), isNull);
      expect(asDouble(double.infinity), isNull);
    });

    test('a JSON double order hint is no longer discarded', () {
      // `int.tryParse(1.0.toString())` returns null, which silently dropped
      // the ordering hint before hardening.
      expect(AiSection.fromMap(<String, dynamic>{'order': 1.0}).order, 1);
      expect(AiItem.fromMap(<String, dynamic>{'order': 2.0}).order, 2);
    });

    test('wrong-typed numeric fields degrade to null', () {
      final item = AiItem.fromMap(<String, dynamic>{
        'price': <String, dynamic>{'a': 1},
        'rating': 'high',
        'reviewCount': true,
        'rawPrice': null,
      });

      expect(item.price, isNull);
      expect(item.rating, isNull);
      expect(item.reviewCount, isNull);
      expect(item.rawPrice, isNull);
    });
  });

  group('map coercion helpers', () {
    test('asStringKeyedMap stringifies non-string keys instead of throwing',
        () {
      expect(
        () => asStringKeyedMap(<int, String>{1: 'a', 2: 'b'}),
        returnsNormally,
      );
      expect(
        asStringKeyedMap(<int, String>{1: 'a', 2: 'b'}),
        <String, dynamic>{'1': 'a', '2': 'b'},
      );
    });

    test('asStringKeyedMap degrades for non-map values', () {
      expect(asStringKeyedMap(null), isEmpty);
      expect(asStringKeyedMap('nope'), isEmpty);
      expect(asStringKeyedMap(<Object?>[1, 2]), isEmpty);
    });

    test('an int-keyed metadata map no longer raises', () {
      expect(
        () => AiResponse.fromMap(
          <String, dynamic>{'metadata': <int, String>{1: 'a'}},
        ),
        returnsNormally,
      );
      expect(
        AiResponse.fromMap(
          <String, dynamic>{'metadata': <int, String>{1: 'a'}},
        ).metadata,
        <String, dynamic>{'1': 'a'},
      );
    });

    test('asList degrades for non-list values', () {
      expect(asList(null), isEmpty);
      expect(asList('nope'), isEmpty);
      expect(asList(<String, dynamic>{'a': 1}), isEmpty);
      expect(asList(<Object?>[1, 2]), <Object?>[1, 2]);
    });

    test('asStringList drops nulls and stringifies the rest', () {
      expect(asStringList(<Object?>['a', null, 2, false]),
          <String>['a', '2', 'false']);
      expect(asStringList(null), isEmpty);
      expect(asStringList('nope'), isEmpty);
    });
  });

  group('dynamically-keyed nested maps are not silently dropped', () {
    test('a Map<dynamic, dynamic> section is parsed, not skipped', () {
      final response = AiResponse.fromMap(<String, dynamic>{
        'sections': <Object?>[
          <dynamic, dynamic>{'title': 'Dyn', 'layout': 'grid'},
        ],
      });

      expect(response.sections, hasLength(1));
      expect(response.sections.single.title, 'Dyn');
      expect(response.sections.single.layout, HomeSectionLayout.grid);
    });

    test('a Map<dynamic, dynamic> item is parsed, not skipped', () {
      final section = AiSection.fromMap(<String, dynamic>{
        'items': <Object?>[
          <dynamic, dynamic>{'id': 'd1', 'type': 'flight', 'title': 'Dyn'},
        ],
      });

      expect(section.items, hasLength(1));
      expect(section.items.single.id, 'd1');
      expect(section.items.single.type, HomeCardType.flight);
    });

    test('a Map<dynamic, dynamic> action is parsed, not skipped', () {
      final item = AiItem.fromMap(<String, dynamic>{
        'actions': <Object?>[
          <dynamic, dynamic>{'type': 'view', 'label': 'Open'},
        ],
      });

      expect(item.actions, hasLength(1));
      expect(item.actions.single.type, 'view');
      expect(item.actions.single.label, 'Open');
    });
  });

  group('actions', () {
    test('actions wrong type degrades to an empty list', () {
      for (final wrong in <Object?>[null, 'nope', 42, <String, dynamic>{}]) {
        expect(
          () => AiItem.fromMap(<String, dynamic>{'actions': wrong}),
          returnsNormally,
        );
        expect(
          AiItem.fromMap(<String, dynamic>{'actions': wrong}).actions,
          isEmpty,
        );
      }
    });

    test('action missing type degrades to an empty string', () {
      final item = AiItem.fromMap(<String, dynamic>{
        'actions': <Object?>[const <String, dynamic>{}],
      });

      expect(item.actions.single.type, '');
      expect(item.actions.single.label, isNull);
      expect(item.actions.single.payload, isEmpty);
    });

    test('action payload wrong type degrades to an empty map', () {
      final item = AiItem.fromMap(<String, dynamic>{
        'actions': <Object?>[
          <String, dynamic>{'type': 'book', 'payload': 'nope'},
        ],
      });

      expect(item.actions.single.payload, isEmpty);
    });
  });

  group('decoded-JSON payloads through the mapper', () {
    test('a valid JSON string parses and maps end to end', () {
      const raw = '{"text":"ok","sections":[{"title":"S","layout":"grid",'
          '"items":[{"id":"1","type":"car","title":"SUV","tags":["a"]}]}]}';

      final response =
          AiResponse.fromMap(jsonDecode(raw) as Map<String, dynamic>);
      final mapped = const AiHomeMapper().toHomeSections(response);

      expect(mapped, hasLength(1));
      expect(mapped.single.layout, HomeSectionLayout.grid);
      expect(mapped.single.items.single.type, HomeCardType.car);
      expect(mapped.single.items.single.tags, <String>['a']);
    });

    test('a wrong-typed JSON payload maps to zero sections', () {
      const raw = '{"text":"ok","sections":"boom"}';

      final response =
          AiResponse.fromMap(jsonDecode(raw) as Map<String, dynamic>);

      expect(response.text, 'ok');
      expect(const AiHomeMapper().toHomeSections(response), isEmpty);
    });

    test('a mixed garbage payload maps without throwing and generates ids', () {
      final response = AiResponse.fromMap(<String, dynamic>{
        'sections': <Object?>[
          <String, dynamic>{'title': 'A', 'items': 'nope'},
          <String, dynamic>{
            'items': <Object?>[
              <String, dynamic>{'type': 'submarine'},
            ],
          },
          null,
          'garbage',
          42,
        ],
      });

      expect(response.sections, hasLength(2));

      final mapped = const AiHomeMapper().toHomeSections(response);

      expect(mapped, hasLength(2));
      expect(mapped[0].items, isEmpty);
      expect(mapped[1].items, hasLength(1));
      expect(mapped[1].items.single.type, HomeCardType.deal);
      expect(mapped[1].items.single.id, 'ai-item-0');
      expect(mapped[1].id, 'ai-section-1');
    });

    test('order hints survive parsing and drive mapper sorting', () {
      final response = AiResponse.fromMap(<String, dynamic>{
        'sections': <Object?>[
          <String, dynamic>{'id': 'second', 'title': 'B', 'order': 2},
          <String, dynamic>{'id': 'first', 'title': 'A', 'order': 1.0},
        ],
      });

      final mapped = const AiHomeMapper().toHomeSections(response);

      expect(mapped.map((s) => s.id).toList(), <String>['first', 'second']);
    });
  });
}
