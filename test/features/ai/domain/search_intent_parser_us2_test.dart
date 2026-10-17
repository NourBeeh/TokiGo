import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/features/ai/domain/search_intent_parser.dart';

/// US-2 §9 — extensive Arabic/English parser coverage: happy paths,
/// incomplete queries, ambiguous queries, invalid dates, invalid passenger
/// counts, mixed Arabic/English, destination-only and service-only
/// queries — plus the full v1 regression vocabulary.
void main() {
  group('US-2 prompt examples (literal)', () {
    test('"فندق رخيص في دبي" → hotel + Dubai + low budget', () {
      final p = SearchIntentParser.parse('فندق رخيص في دبي');
      expect(p.service, 'hotel');
      expect(p.destination, 'Dubai');
      expect(p.budgetBand, 'low');
      expect(p.origin, isNull); // never invented
    });

    test('"عايز فندق في دبي 3 ليالي" → hotel + Dubai + 3 nights', () {
      final p = SearchIntentParser.parse('عايز فندق في دبي 3 ليالي');
      expect(p.service, 'hotel');
      expect(p.destination, 'Dubai');
      expect(p.durationNights, 3);
    });

    test('"from Cairo to Dubai" → origin + destination', () {
      final p = SearchIntentParser.parse('flight from Cairo to Dubai');
      expect(p.service, 'flight');
      expect(p.origin, 'cairo');
      expect(p.destination, 'dubai');
    });

    test('"رحلة من القاهرة لدبي من 10 لـ 15 أكتوبر" → full interval', () {
      final p = SearchIntentParser.parse('رحلة من القاهرة لدبي من 10 لـ 15 أكتوبر');
      expect(p.service, 'flight');
      expect(p.destination, 'دبي');
      expect(p.date, isNotNull);
      expect(p.returnDate, isNotNull);
      expect(p.returnDate!.difference(p.date!).inDays, 5);
      expect(p.date!.month, 10);
      expect(p.date!.day, 10);
      expect(p.returnDate!.day, 15);
    });
  });

  group('Arabic-Indic digits + variants', () {
    test('Arabic-Indic digits normalize (١٥ أكتوبر)', () {
      final p = SearchIntentParser.parse('رحلة من القاهرة لدبي من ١٠ لـ ١٥ أكتوبر');
      expect(p.date, isNotNull);
      expect(p.date!.day, 10);
      expect(p.returnDate!.day, 15);
    });

    test(' colloquial city aliases collapse to canonical names', () {
      final p = SearchIntentParser.parse('فنادق في شرم');
      expect(p.destination, 'Sharm El Sheikh');
    });

    test('"إستنبول" and "استانبول" both resolve', () {
      expect(
        SearchIntentParser.parse('فندق في إستنبول').destination,
        'Istanbul',
      );
      expect(
        SearchIntentParser.parse('فندق في استانبول').destination,
        'Istanbul',
      );
    });
  });

  group('English happy paths', () {
    test('"hotels in dubai 2 nights" → hotel + duration', () {
      final p = SearchIntentParser.parse('hotels in dubai 2 nights');
      expect(p.service, 'hotel');
      expect(p.destination, 'Dubai');
      expect(p.durationNights, 2);
    });

    test('"cheap hotel in cairo" → low budget', () {
      final p = SearchIntentParser.parse('cheap hotel in cairo');
      expect(p.service, 'hotel');
      expect(p.destination, 'Cairo');
      expect(p.budgetBand, 'low');
    });

    test('"luxury hotel in riyadh" → high budget', () {
      final p = SearchIntentParser.parse('luxury hotel in riyadh');
      expect(p.budgetBand, 'high');
    });

    test('"فندق فاخر في جدة" → high budget (Arabic)', () {
      final p = SearchIntentParser.parse('فندق فاخر في جدة');
      expect(p.service, 'hotel');
      expect(p.destination, 'Jeddah');
      expect(p.budgetBand, 'high');
    });

    test('"hotel 5 stars in dubai" → minStars', () {
      final p = SearchIntentParser.parse('hotel 5 stars in dubai');
      expect(p.minStars, 5);
    });

    test('"فندق 4 نجوم في دبي" → minStars (Arabic)', () {
      final p = SearchIntentParser.parse('فندق 4 نجوم في دبي');
      expect(p.minStars, 4);
    });

    test('"rent a car from riyadh airport to city center" (v1 regression)', () {
      final p = SearchIntentParser.parse('rent a car from riyadh airport to city center');
      expect(p.service, 'car');
      expect(p.origin, 'riyadh airport');
      expect(p.destination, 'city center');
    });

    test('"hotel from cairo to dubai" keeps from-to semantics (v1)', () {
      final p = SearchIntentParser.parse('hotel from cairo to dubai');
      expect(p.service, 'hotel');
      expect(p.origin, 'cairo');
      expect(p.destination, 'dubai');
    });
  });

  group('mixed Arabic/English', () {
    test('"فندق in دبي 3 ليالي" — mixed script', () {
      final p = SearchIntentParser.parse('فندق in دبي 3 ليالي');
      expect(p.service, 'hotel');
      expect(p.destination, 'Dubai');
      expect(p.durationNights, 3);
    });

    test('"hotels في القاهرة" — English service + Arabic place', () {
      final p = SearchIntentParser.parse('hotels في القاهرة');
      expect(p.service, 'hotel');
      expect(p.destination, 'Cairo');
    });
  });

  group('incomplete queries (gaps — never invented)', () {
    test('"فندق" only → service, no destination', () {
      final p = SearchIntentParser.parse('فندق');
      expect(p.service, 'hotel');
      expect(p.destination, isNull);
      expect(p.origin, isNull);
    });

    test('"فنادق في دبي" without dates → destination present, date null', () {
      final p = SearchIntentParser.parse('فنادق في دبي');
      expect(p.service, 'hotel');
      expect(p.destination, 'Dubai');
      expect(p.date, isNull);
      expect(p.durationNights, isNull);
    });

    test('service-only: "طيران" → flight, no endpoints', () {
      final p = SearchIntentParser.parse('طيران');
      expect(p.service, 'flight');
      expect(p.origin, isNull);
      expect(p.destination, isNull);
    });

    test('"flight from cairo" alone → origin captured, destination null', () {
      final p = SearchIntentParser.parse('flight from cairo');
      expect(p.service, 'flight');
      expect(p.origin, 'cairo');
      expect(p.destination, isNull);
    });
  });

  group('ambiguous queries', () {
    test('"عايز أسافر" → no intent', () {
      final p = SearchIntentParser.parse('عايز أسافر');
      expect(p.isValid, isFalse);
      expect(p.service, isNull);
    });

    test('"nice weather somewhere" → no intent', () {
      expect(SearchIntentParser.parse('nice weather somewhere').isValid,
          isFalse);
    });

    test('"random words here" → no intent', () {
      expect(SearchIntentParser.parse('random words here').isValid, isFalse);
    });

    test('destination-only word with no service stays non-intent', () {
      // "Dubai" alone names a place but no service — the surface treats it
      // as a quick search, not a structured intent.
      expect(SearchIntentParser.parse('dubai').isValid, isFalse);
    });
  });

  group('invalid values are rejected safely (§5)', () {
    test('past dates are dropped', () {
      final p = SearchIntentParser.parse('hotel in dubai 01/01/2020');
      expect(p.date, isNull);
    });

    test('impossible passenger counts are dropped', () {
      final p = SearchIntentParser.parse('flight from cairo to dubai 300 passenger');
      expect(p.passengers, isNull);
    });

    test('zero passengers are dropped', () {
      final p = SearchIntentParser.parse('flight 0 passenger');
      expect(p.passengers, isNull);
    });

    test('impossible night counts are dropped', () {
      final p = SearchIntentParser.parse('hotel in dubai 99 nights');
      expect(p.durationNights, isNull);
    });

    test('impossible room counts are dropped', () {
      final p = SearchIntentParser.parse('hotel in dubai 10 غرف');
      expect(p.rooms, isNull);
    });

    test('impossible stars are dropped', () {
      final p = SearchIntentParser.parse('hotel in dubai 9 stars');
      expect(p.minStars, isNull);
    });

    test('"شخصين" resolves to exactly two', () {
      final p = SearchIntentParser.parse('فندق في دبي لشخصين');
      expect(p.passengers, 2);
    });

    test('plausible passengers pass through', () {
      final p = SearchIntentParser.parse('flight from cairo to dubai 4 passenger');
      expect(p.passengers, 4);
    });
  });

  group('amenities vocabulary', () {
    test('"فندق في دبي بمسبح" → Pool amenity', () {
      final p = SearchIntentParser.parse('فندق في دبي بمسبح');
      expect(p.amenities, contains('Pool'));
    });

    test('"hotel in dubai with wifi" → WiFi amenity', () {
      final p = SearchIntentParser.parse('hotel in dubai with wifi');
      expect(p.amenities, contains('WiFi'));
    });
  });

  group('Arabic date intervals', () {
    test('cross-month interval "من 28 لـ 3 نوفمبر" rolls forward', () {
      final p = SearchIntentParser.parse('رحلة من 28 لـ 3 نوفمبر');
      expect(p.date, isNotNull);
      expect(p.returnDate, isNotNull);
      expect(p.returnDate!.isAfter(p.date!), isTrue);
    });

    test('interval without month picks the next plausible month', () {
      final p = SearchIntentParser.parse('رحلة من 10 لـ 15');
      expect(p.date, isNotNull);
      expect(p.returnDate!.isAfter(p.date!), isTrue);
    });

    test('impossible interval days (32 لـ 40) are rejected', () {
      final p = SearchIntentParser.parse('رحلة من 32 لـ 40 أكتوبر');
      expect(p.date, isNull);
      expect(p.returnDate, isNull);
    });
  });

  group('numeric fragments are never places', () {
    test('"رحلة من 10 لـ 15" (no cities) → endpoints null, dates captured', () {
      final p = SearchIntentParser.parse('رحلة من 10 لـ 15');
      expect(p.service, 'flight');
      expect(p.origin, isNull);
      expect(p.destination, isNull);
      expect(p.date, isNotNull);
      expect(p.returnDate, isNotNull);
    });

    test('"flight from 7 to 12 october" (no cities) → endpoints null', () {
      final p = SearchIntentParser.parse('flight from 7 to 12 october');
      expect(p.service, 'flight');
      expect(p.origin, isNull);
      expect(p.destination, isNull);
    });
  });

  group('rooms + guests together', () {
    test('"فندق في دبي 2 غرف 4 أشخاص"', () {
      final p = SearchIntentParser.parse('فندق في دبي 2 غرف 4 أشخاص');
      expect(p.service, 'hotel');
      expect(p.destination, 'Dubai');
      expect(p.rooms, 2);
      expect(p.passengers, 4);
    });
  });
}
