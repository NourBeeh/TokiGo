import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/memory/memory_model.dart';
import 'package:tokigo/features/ai/domain/explicit_memory_view.dart';

/// 2C-C2 — ExplicitMemoryView + ExplicitMemoryInput domain tests.
///
/// Covers: vocabulary filtering (only the 3 allowed kinds pass), suffix
/// stripping from memory keys, human-readable rendering per kind (never raw
/// JSON), and the full validation matrix mirroring the backend
/// conversation_facts.ts limits (destination ≤ 80, budget numbers + min≤max,
/// styles split/count/length).
MemoryRecord _record({
  required String id,
  required String type,
  required String key,
  Map<String, dynamic> value = const {},
  String source = 'ai_conversation',
  String? expiresAt,
}) {
  return MemoryRecord(
    id: id,
    type: type,
    key: key,
    value: value,
    source: source,
    confidence: 0.9,
    expiresAt: expiresAt,
  );
}

void main() {
  group('ExplicitMemoryView.fromRecord — vocabulary filter', () {
    test('accepts the three allowed kinds with subject suffixes', () {
      final destination = ExplicitMemoryView.fromRecord(_record(
        id: '1',
        type: 'conversation',
        key: 'preferred_destination:paris',
        value: const {'destination': 'Paris'},
      ));
      final budget = ExplicitMemoryView.fromRecord(_record(
        id: '2',
        type: 'conversation',
        key: 'preferred_budget',
        value: const {'min': 100, 'max': 500},
      ));
      final style = ExplicitMemoryView.fromRecord(_record(
        id: '3',
        type: 'conversation',
        key: 'preferred_travel_style',
        value: const {'styles': ['Luxury', 'Adventure']},
      ));

      expect(destination?.kind, 'preferred_destination');
      expect(budget?.kind, 'preferred_budget');
      expect(style?.kind, 'preferred_travel_style');
    });

    test('rejects keys outside the 2C vocabulary', () {
      expect(
        ExplicitMemoryView.fromRecord(_record(
          id: '4',
          type: 'behavior',
          key: 'hotel_search:paris',
        )),
        isNull,
      );
      expect(
        ExplicitMemoryView.fromRecord(_record(
          id: '5',
          type: 'derived',
          key: 'derived_preference',
        )),
        isNull,
      );
      expect(
        ExplicitMemoryView.fromRecord(_record(
          id: '6',
          type: 'behavior',
          key: 'preferred_hotel_style',
        )),
        isNull,
      );
    });

    test('rejects conversation records whose type is foreign', () {
      // A behavioral row that somehow carries a 2C key stays invisible.
      expect(
        ExplicitMemoryView.fromRecord(_record(
          id: '7',
          type: 'behavior',
          key: 'preferred_budget',
        )),
        isNull,
      );
    });
  });

  group('ExplicitMemoryView rendering — never raw fields', () {
    test('destination renders the value only', () {
      final view = ExplicitMemoryView.fromRecord(_record(
        id: 'a',
        type: 'conversation',
        key: 'preferred_destination:paris',
        value: const {'destination': 'Paris'},
      ))!;
      expect(view.displayValue, 'Paris');
      expect(view.title, 'Preferred destination');
      // The raw record source / confidence never leak into rendering.
      expect(view.displayValue.contains('ai_conversation'), isFalse);
      // The id ('a') is a substring of nothing meaningful here — assert the
      // whole string instead (a full-equality check is the honest leak test).
      expect(view.displayValue, 'Paris');
    });

    test('budget renders both bounds, single bounds, and empty', () {
      MemoryRecord budget(Map<String, dynamic> value) => _record(
            id: 'b',
            type: 'conversation',
            key: 'preferred_budget',
            value: value,
          );

      expect(
        ExplicitMemoryView.fromRecord(
          budget(const {'min': 100, 'max': 500.5}),
        )?.displayValue,
        '100 – 500.5',
      );
      expect(
        ExplicitMemoryView.fromRecord(
          budget(const {'min': 80}),
        )?.displayValue,
        'From 80',
      );
      expect(
        ExplicitMemoryView.fromRecord(
          budget(const {'max': 900}),
        )?.displayValue,
        'Up to 900',
      );
      expect(
        ExplicitMemoryView.fromRecord(budget(const {}))?.displayValue,
        '',
      );
    });

    test('styles render as a comma list', () {
      final view = ExplicitMemoryView.fromRecord(_record(
        id: 'c',
        type: 'conversation',
        key: 'preferred_travel_style',
        value: const {'styles': ['Luxury', 'Beach', 'Adventure']},
      ))!;
      expect(view.displayValue, 'Luxury, Beach, Adventure');
    });
  });

  group('ExplicitMemoryInput.validate — backend limits mirrored', () {
    test('destination: empty and over-limit rejected, valid passes', () {
      expect(
        ExplicitMemoryInput.validate(
          kind: 'preferred_destination',
          destination: '   ',
        ),
        isNotNull,
      );
      expect(
        ExplicitMemoryInput.validate(
          kind: 'preferred_destination',
          destination: 'A' * 81,
        ),
        isNotNull,
      );
      expect(
        ExplicitMemoryInput.validate(
          kind: 'preferred_destination',
          destination: '  Paris ',
        ),
        isNull,
      );
    });

    test('budget: non-numbers, missing bounds, min>max rejected', () {
      expect(
        ExplicitMemoryInput.validate(
          kind: 'preferred_budget',
          minBudget: 'abc',
        ),
        isNotNull,
      );
      expect(
        ExplicitMemoryInput.validate(kind: 'preferred_budget'),
        isNotNull, // no bounds at all
      );
      expect(
        ExplicitMemoryInput.validate(
          kind: 'preferred_budget',
          minBudget: '500',
          maxBudget: '100',
        ),
        isNotNull,
      );
      expect(
        ExplicitMemoryInput.validate(
          kind: 'preferred_budget',
          minBudget: '100',
          maxBudget: '500',
        ),
        isNull,
      );
      expect(
        ExplicitMemoryInput.validate(kind: 'preferred_budget', minBudget: '1'),
        isNull, // min only is valid
      );
    });

    test('styles: empty, over-count, over-length rejected; split works', () {
      expect(
        ExplicitMemoryInput.validate(
          kind: 'preferred_travel_style',
          styles: ' , ,',
        ),
        isNotNull,
      );
      final many = List.generate(61, (i) => 's$i').join(', ');
      expect(
        ExplicitMemoryInput.validate(
          kind: 'preferred_travel_style',
          styles: many,
        ),
        isNotNull,
      );
      expect(
        ExplicitMemoryInput.validate(
          kind: 'preferred_travel_style',
          styles: 'A' * 61,
        ),
        isNotNull,
      );
      expect(
        ExplicitMemoryInput.validate(
          kind: 'preferred_travel_style',
          styles: 'Luxury, Adventure',
        ),
        isNull,
      );
    });

    test('unknown kind rejected', () {
      expect(
        ExplicitMemoryInput.validate(kind: 'preferred_hotel_style'),
        isNotNull,
      );
    });
  });

  group('ExplicitMemoryInput.buildValue — structured output', () {
    test('destination trimmed', () {
      final value = ExplicitMemoryInput.buildValue(
        kind: 'preferred_destination',
        destination: ' Paris ',
      );
      expect(value, const {'destination': 'Paris'});
    });

    test('budget parses numbers and omits absent bounds', () {
      expect(
        ExplicitMemoryInput.buildValue(
          kind: 'preferred_budget',
          minBudget: '100',
          maxBudget: '500',
        ),
        const {'min': 100.0, 'max': 500.0},
      );
      expect(
        ExplicitMemoryInput.buildValue(kind: 'preferred_budget', minBudget: '7'),
        const {'min': 7.0},
      );
    });

    test('styles split on comma and Arabic comma, trimmed, no empties', () {
      expect(
        ExplicitMemoryInput.buildValue(
          kind: 'preferred_travel_style',
          styles: 'Luxury ، Beach,  Adventure ,',
        ),
        const {'styles': ['Luxury', 'Beach', 'Adventure']},
      );
    });
  });
}
