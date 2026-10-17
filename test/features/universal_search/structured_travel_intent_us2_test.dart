import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/features/universal_search/domain/structured_travel_intent.dart';

/// US-2 §1 — the extended typed intent: completeness rules per vertical,
/// effective end dates, immutable patches and the budget band vocabulary.
void main() {
  final oct = DateTime(2026, 10, 10);

  StructuredTravelIntent hotel({
    String? destination = 'Dubai',
    DateTime? date,
    DateTime? returnDate,
    int? durationNights,
    int? passengers,
    int? rooms,
    IntentBudgetBand budget = IntentBudgetBand.none,
    double? minStars,
    List<String> amenities = const [],
  }) {
    return StructuredTravelIntent(
      type: 'hotel',
      destination: destination,
      date: date,
      returnDate: returnDate,
      durationNights: durationNights,
      passengers: passengers,
      rooms: rooms,
      budget: budget,
      minStars: minStars,
      amenities: amenities,
    );
  }

  group('missingFields per vertical (no invented facts)', () {
    test('hotel with destination is complete; without it gaps', () {
      expect(hotel().missingFields(), isEmpty);
      expect(hotel(destination: null).missingFields(),
          <IntentGap>[IntentGap.destination]);
    });

    test('flight requires BOTH endpoints', () {
      final none = StructuredTravelIntent(type: 'flight');
      expect(none.missingFields(), containsAll(<IntentGap>[
        IntentGap.origin,
        IntentGap.destination,
      ]));
      final half = StructuredTravelIntent(
        type: 'flight',
        origin: 'Cairo',
      );
      expect(half.missingFields(), <IntentGap>[IntentGap.destination]);
      final full = StructuredTravelIntent(
        type: 'flight',
        origin: 'Cairo',
        destination: 'Dubai',
      );
      expect(full.missingFields(), isEmpty);
    });

    test('car gaps only when neither endpoint is present', () {
      final bare = StructuredTravelIntent(type: 'car');
      expect(bare.missingFields(), <IntentGap>[IntentGap.destination]);
      final withOrigin = StructuredTravelIntent(type: 'car', origin: 'Riyadh');
      expect(withOrigin.missingFields(), isEmpty);
    });

    test('package flags unsupported instead of pretending to execute', () {
      final pkg = StructuredTravelIntent(type: 'package', destination: 'Dubai');
      expect(
        pkg.missingFields(),
        <IntentGap>[IntentGap.unsupportedPackage],
      );
      expect(pkg.isComplete, isFalse);
    });
  });

  group('effectiveEndDate', () {
    test('explicit return date wins', () {
      final end = oct.add(const Duration(days: 9));
      final intent = hotel(date: oct, returnDate: end);
      expect(intent.effectiveEndDate(oct), end);
    });

    test('parsed duration wins over the default', () {
      final intent = hotel(date: oct, durationNights: 3);
      expect(
        intent.effectiveEndDate(oct).difference(oct).inDays,
        3,
      );
    });

    test('vertical default applies last', () {
      expect(
        hotel(date: oct).effectiveEndDate(oct).difference(oct).inDays,
        2,
      );
      expect(
        hotel(date: oct).effectiveEndDate(oct, defaultNights: 3)
            .difference(oct)
            .inDays,
        3,
      );
    });
  });

  group('immutable patches (US-2 §8)', () {
    test('copyWith patches only the named fields', () {
      final base = hotel(
        date: oct,
        passengers: 2,
        budget: IntentBudgetBand.low,
      );
      final patched = base.copyWith(budget: IntentBudgetBand.high);
      expect(base.budget, IntentBudgetBand.low); // original untouched
      expect(patched.budget, IntentBudgetBand.high);
      expect(patched.passengers, 2);
      expect(patched.date, oct);
    });

    test('amenities patch extends, never replaces silently', () {
      final base = hotel(amenities: <String>['WiFi']);
      final patched = base.copyWith(
        amenities: <String>[...base.amenities, 'Airport transfer'],
      );
      expect(patched.amenities, <String>['WiFi', 'Airport transfer']);
      expect(base.amenities, <String>['WiFi']);
    });
  });
}
