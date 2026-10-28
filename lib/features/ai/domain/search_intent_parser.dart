/// Parser that extracts search intent from natural language user queries
/// Supports both English and Arabic queries for flights, hotels, and car rentals
library;

import 'package:intl/intl.dart';

/// Result of parsing a search intent
class ParsedSearchIntent {
  final String? service; // 'flight', 'hotel', 'car', or null if unknown
  final String? origin;
  final String? destination;
  final DateTime? date;
  final DateTime? returnDate;
  final int? passengers;
  final int? durationNights;
  final int? rooms;
  final String? budgetBand; // 'low' | 'medium' | 'high' | null
  final double? minStars;
  final List<String> amenities;

  const ParsedSearchIntent({
    this.service,
    this.origin,
    this.destination,
    this.date,
    this.returnDate,
    this.passengers,
    this.durationNights,
    this.rooms,
    this.budgetBand,
    this.minStars,
    this.amenities = const [],
  });

  bool get isValid => service != null;
}

class SearchIntentParser {
  // Common date formats to try parsing
  static final _dateFormats = [
    'dd MMMM yyyy',
    'dd/MM/yyyy',
    'MM/dd/yyyy',
    'yyyy-MM-dd',
    'd MMM yyyy',
  ];

  // Service keywords in multiple languages
  static const _flightKeywords = {
    'flight',
    'flights',
    'طائرة',
    'رحلة طيران',
    'طيران',
    'رحلة',
  };
  static const _hotelKeywords = {'hotel', 'hotels', 'فندق', 'فنادق'};
  static const _carKeywords = {
    'car',
    'cars',
    'rent a car',
    'سيارة',
    'إيجار سيارة',
  };

  // Origin/destination indicators
  static const _fromKeywords = {'from', 'من'};
  static const _toKeywords = {'to', 'إلى', 'الى', 'لـ'};

  // ---------------------------------------------------------------------
  // US-2 additions
  // ---------------------------------------------------------------------

  /// "in/at/في + destination" pattern vocabulary. A fixed dictionary —
  /// no ML, no invented places. Aliases collapse to the canonical name.
  static const Map<String, String> _placeAliases = <String, String>{
    'dubai': 'Dubai',
    'دبي': 'Dubai',
    'ديبي': 'Dubai',
    'cairo': 'Cairo',
    'القاهرة': 'Cairo',
    'قاهرة': 'Cairo',
    'riyadh': 'Riyadh',
    'الرياض': 'Riyadh',
    'jeddah': 'Jeddah',
    'جدة': 'Jeddah',
    'جده': 'Jeddah',
    'sharm el sheikh': 'Sharm El Sheikh',
    'شرم الشيخ': 'Sharm El Sheikh',
    'شرم': 'Sharm El Sheikh',
    'hurghada': 'Hurghada',
    'الغردقة': 'Hurghada',
    'غردقة': 'Hurghada',
    'alexandria': 'Alexandria',
    'الإسكندرية': 'Alexandria',
    'الاسكندرية': 'Alexandria',
    'اسكندرية': 'Alexandria',
    'luxor': 'Luxor',
    'الأقصر': 'Luxor',
    'اقصر': 'Luxor',
    'الاقصر': 'Luxor',
    'aswan': 'Aswan',
    'أسوان': 'Aswan',
    'اسوان': 'Aswan',
    'istanbul': 'Istanbul',
    'إستنبول': 'Istanbul',
    'استنبول': 'Istanbul',
    'استانبول': 'Istanbul',
    'london': 'London',
    'لندن': 'London',
    'paris': 'Paris',
    'باريس': 'Paris',
    'rome': 'Rome',
    'روما': 'Rome',
    'athens': 'Athens',
    'أثينا': 'Athens',
    'اثينا': 'Athens',
    'doha': 'Doha',
    'الدوحة': 'Doha',
    'amman': 'Amman',
    'عمّان': 'Amman',
    'عمان': 'Amman',
    'new york': 'New York',
    'نيويورك': 'New York',
    'نيو يورك': 'New York',
    'bangkok': 'Bangkok',
    'بانكوك': 'Bangkok',
    'mecca': 'Mecca',
    'مكة': 'Mecca',
    'madinah': 'Madinah',
    'المدينة': 'Madinah',
    'kuwait': 'Kuwait',
    'الكويت': 'Kuwait',
    'abu dhabi': 'Abu Dhabi',
    'أبوظبي': 'Abu Dhabi',
    'ابوظبي': 'Abu Dhabi',
  };

  static const _inKeywords = {'in', 'at', 'في'};

  // Budget band vocabulary (US-2 §2) — controlled, not free-form.
  static const _budgetLowKeywords = {
    'cheap',
    'cheapest',
    'budget',
    'رخيص',
    'رخيصة',
    'أرخص',
    'ارخص',
    'اقتصادي',
  };
  static const _budgetHighKeywords = {
    'luxury',
    'luxurious',
    'premium',
    'فاخر',
    'فاخرة',
    'أفخم',
    'افخم',
    'رخيم',
  };
  static const _budgetMediumKeywords = {'medium', 'moderate', 'متوسط', 'وسط'};

  // Stars vocabulary.
  static final RegExp _starsPattern = RegExp(
    r'(\d(?:\.\d)?)\s*(?:نجوم|نجمة|نجموم|stars?|star)',
  );

  // Duration vocabulary: "3 ليالي" / "3 nights" / "لـ 3 ليالي".
  static final RegExp _nightsPattern = RegExp(
    r'(\d+)\s*(?:ليالي|ليالٍ|ليله|لياليّ|nights?)',
  );

  // Arabic-Indic digits → Western (٠١٢٣٤٥٦٧٨٩).
  static String _normalizeDigits(String text) {
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const western = '0123456789';
    return text.replaceAllMapped(
      RegExp('[$arabicIndic]'),
      (m) => western[arabicIndic.indexOf(m.group(0)!)],
    );
  }

  // ---------------------------------------------------------------------
  // Main entry
  // ---------------------------------------------------------------------

  /// Pre-normalization: Arabic commonly fuses the "ل" (to) preposition into
  /// the place name ("لدبي" = "لـ دبي"). Un-fuse every known alias so the
  /// from/to extraction and the dictionary both see the canonical token.
  /// Word-start only: "القاهرة" must NOT match the fused "لقاهرة" (the
  /// "ال" prefix) — the character before the fused form may not be an
  /// Arabic letter.
  static String _unfuseToPreposition(String lowerQuery) {
    final arabicLetter = RegExp(r'[\u0621-\u064A]');
    var result = lowerQuery;
    for (final alias in _placeAliases.keys) {
      if (alias.contains(' ')) continue;
      final fused = 'ل$alias';
      var idx = result.indexOf(fused);
      while (idx >= 0) {
        final prevIsLetter = idx > 0 && arabicLetter.hasMatch(result[idx - 1]);
        if (!prevIsLetter) {
          result = result.replaceRange(idx, idx + fused.length, 'لـ $alias');
          // The replacement grew by 2 chars — skip past it.
          idx = result.indexOf(fused, idx + fused.length + 2);
        } else {
          idx = result.indexOf(fused, idx + 1);
        }
      }
    }
    return result;
  }

  /// Parse a natural language query into a structured search intent
  static ParsedSearchIntent parse(String query) {
    final digitQuery = _normalizeDigits(query);
    final lowerQuery = _unfuseToPreposition(digitQuery.toLowerCase());
    String? service = _detectService(lowerQuery);

    if (service == null) {
      return const ParsedSearchIntent();
    }

    // Extract origin and destination
    var locations = _extractLocations(lowerQuery);
    var origin = locations.$1;
    var destination = locations.$2;

    // US-2: a numeric "destination" is a date fragment stolen by the
    // from/to split ("رحلة من 10 لـ 15") — reject it, never search for a
    // number as a place.
    if (destination != null && _isNumericFragment(destination)) {
      destination = null;
    }

    // US-2: "in/at/في <place>" — fill the destination when the from-to
    // pattern found nothing (e.g. "فندق رخيص في دبي", "hotels in dubai").
    if (destination == null) {
      destination = _extractInPlace(lowerQuery);
      // A lone "from X" with no "to" lands in origin — for hotels/cars
      // the location the user named IS the destination.
      if (destination != null && (origin == null || service != 'flight')) {
        origin = null;
      }
    }

    // US-2: a numeric/date "origin" is a fragment stolen by the from/to
    // split ("رحلة من 10 لـ 15 أكتوبر" without cities) — reject it, never
    // treat a date as a place.
    if (origin != null &&
        (_isNumericFragment(origin) || _looksLikeDateFragment(origin))) {
      origin = null;
    }

    // Extract dates (existing formats + the US-2 Arabic interval).
    final dates = _extractDates(digitQuery);
    var date = dates.$1;
    var returnDate = dates.$2;

    // US-2 Arabic interval support: "من 10 لـ 15 أكتوبر".
    final interval = _extractArabicInterval(digitQuery);
    if (interval != null) {
      date ??= interval.$1;
      returnDate ??= interval.$2;
    }

    // US-2 §5 validation — impossible values are dropped, never guessed.
    final now = DateTime.now();
    if (date != null && date.isBefore(DateTime(now.year, now.month, now.day))) {
      date = null;
      returnDate = null;
    }
    if (date != null && returnDate != null && !returnDate.isAfter(date)) {
      returnDate = null;
    }

    // Extract number of passengers/guests
    var passengers = _extractPassengers(lowerQuery);

    // US-2: duration nights + rooms + budget + stars + amenities.
    final durationNights = _extractNights(lowerQuery);
    final rooms = _extractRooms(lowerQuery);
    final budgetBand = _detectBudgetBand(lowerQuery);
    final minStars = _extractStars(lowerQuery);
    final amenities = _extractAmenities(lowerQuery);

    return ParsedSearchIntent(
      service: service,
      origin: origin,
      destination: destination,
      date: date,
      returnDate: returnDate,
      passengers: passengers,
      durationNights: durationNights,
      rooms: rooms,
      budgetBand: budgetBand,
      minStars: minStars,
      amenities: amenities,
    );
  }

  static String? _detectService(String lowerQuery) {
    if (_flightKeywords.any((keyword) => lowerQuery.contains(keyword))) {
      return 'flight';
    }
    if (_hotelKeywords.any((keyword) => lowerQuery.contains(keyword))) {
      return 'hotel';
    }
    if (_carKeywords.any((keyword) => lowerQuery.contains(keyword))) {
      return 'car';
    }
    return null;
  }

  static (String?, String?) _extractLocations(String lowerQuery) {
    String? origin;
    String? destination;

    // Split query to find from-to pattern
    for (final fromKeyword in _fromKeywords) {
      if (lowerQuery.contains(fromKeyword)) {
        // Prefer the FIRST "from" occurrence: a later one is likely a DATE
        // range ("رحلة من القاهرة لدبي من 10 لـ 15 أكتوبر") and must not
        // steal the location pair (US-2).
        final afterFrom = lowerQuery.split(fromKeyword)[1].trim();
        for (final toKeyword in _toKeywords) {
          final toIdx = afterFrom.indexOf(toKeyword);
          if (toIdx >= 0) {
            // Split on the FIRST "to" only: a later occurrence may belong to
            // a date range ("لـ 15 أكتوبر") and must not steal the pair.
            origin = afterFrom.substring(0, toIdx).trim();
            destination = afterFrom.substring(toIdx + toKeyword.length).trim();
            return (origin, destination);
          }
        }
        // If no "to" found, take what's after from as origin
        origin = afterFrom.split(' ').take(2).join(' ').trim();
      }
    }

    // US-2: "to <place>" without a "from" — a lone destination ("flight to
    // dubai"). Only city-like tokens qualify (a date fragment like "15"
    // must never become a place).
    if (destination == null && origin == null) {
      for (final toKeyword in _toKeywords) {
        final idx = lowerQuery.indexOf(toKeyword);
        if (idx >= 0) {
          final candidate = lowerQuery
              .substring(idx + toKeyword.length)
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .join(' ')
              .trim();
          if (candidate.isNotEmpty && !_isNumericFragment(candidate)) {
            destination = candidate;
            break;
          }
        }
      }
    }

    return (origin, destination);
  }

  /// `in/at/في` followed by a place — resolves through the place
  /// dictionary only.
  static String? _extractInPlace(String lowerQuery) {
    for (final inKeyword in _inKeywords) {
      var idx = lowerQuery.indexOf(inKeyword);
      while (idx >= 0) {
        final after = lowerQuery.substring(idx + inKeyword.length).trim();
        // Try progressively longer slices against the dictionary.
        final words = after.split(RegExp(r'\s+'));
        final buffer = StringBuffer();
        for (final word in words) {
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(word);
          final candidate = buffer.toString().replaceAll(
            RegExp(r'[.,!?،؟]+$'),
            '',
          );
          final canonical = _placeAliases[candidate];
          if (canonical != null) return canonical;
          if (buffer.length > 24) break; // beyond any alias
        }
        idx = lowerQuery.indexOf(inKeyword, idx + inKeyword.length);
      }
    }
    return null;
  }

  /// True when a captured "origin" is actually a date fragment stolen by
  /// the from/to split (Arabic interval queries).
  static bool _looksLikeDateFragment(String text) {
    final t = text.trim();
    if (t.isEmpty) return true;
    return RegExp(r'^\d{1,2}(\s|$)|^\d').hasMatch(t) &&
        t.length <= 12 &&
        !RegExp(
          r'[a-zA-Z\u0600-\u06FF]{3,}',
        ).hasMatch(t.replaceAll(RegExp(r'^\d+\s*'), ''));
  }

  /// True when a captured endpoint is purely numeric ("15", "15 أكتوبر"
  /// dates are numbers + a month word) — a number is never a place.
  static bool _isNumericFragment(String text) {
    final t = text.trim();
    if (t.isEmpty) return true;
    if (!RegExp(r'^\d').hasMatch(t)) return false;
    // Digits + optional month words only → numeric, not a place.
    final stripped = t.replaceAll(RegExp(r'^[\d\s]+'), '');
    return stripped.isEmpty ||
        _arabicMonths.any((m) => stripped.contains(m)) ||
        RegExp(
          r'^(october|november|december|january|february|march|april|may|june|july|august|september)$',
        ).hasMatch(stripped);
  }

  /// Arabic month names for interval parsing.
  static const List<String> _arabicMonths = <String>[
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'ابريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'اغسطس',
    'سبتمبر',
    'أكتوبر',
    'اكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  /// "من 10 لـ 15 أكتوبر" / "من 10 إلى 15 اكتوبر" — day[-month]
  /// [day2 [month]] interval. The second month may be omitted (shares the
  /// first's).
  static (DateTime, DateTime)? _extractArabicInterval(String query) {
    final pattern = RegExp(
      r'من\s*(\d{1,2})\s*(?:[\w\u0600-\u06FF]+)?\s*(?:ل|إلى|الى|لـ)\s*(\d{1,2})\s*([\w\u0600-\u06FF]*)',
    );
    final match = pattern.firstMatch(query);
    if (match == null) return null;

    final day1 = int.tryParse(match.group(1)!);
    final day2 = int.tryParse(match.group(2)!);
    if (day1 == null || day2 == null) return null;
    if (day1 < 1 || day1 > 31 || day2 < 1 || day2 > 31) return null;

    final monthWord = match.group(3)?.trim();
    final monthIdx = monthWord == null || monthWord.isEmpty
        ? null
        : _arabicMonths.indexWhere((m) => monthWord.contains(m));
    if (monthWord != null && monthWord.isNotEmpty && monthIdx == -1) {
      return null; // not a month — not a date range
    }

    final now = DateTime.now();
    var month = monthIdx != null && monthIdx >= 0
        ? _arabicMonthNumber(_arabicMonths[monthIdx])
        : null;
    month ??= (day1 >= now.day) ? now.month : now.month + 1;
    if (month > 12) month = 1;

    var start = _safeDate(now.year, month, day1);
    var end = _safeDate(now.year, month, day2);
    if (start == null || end == null) return null;
    if (end.isBefore(start)) {
      // Crossed a month boundary ("من 28 لـ 3 نوفمبر").
      end = _safeDate(end.year, end.month + 1 > 12 ? 1 : end.month + 1, day2);
      if (end == null || end.isBefore(start)) return null;
    }
    if (start.isBefore(DateTime(now.year, now.month, now.day))) {
      // Rolled into next year.
      start = DateTime(start.year + 1, start.month, start.day);
      end = DateTime(end.year + 1, end.month, end.day);
    }
    return (start, end);
  }

  static int? _arabicMonthNumber(String name) {
    const months = <String, int>{
      'يناير': 1,
      'فبراير': 2,
      'مارس': 3,
      'أبريل': 4,
      'ابريل': 4,
      'مايو': 5,
      'يونيو': 6,
      'يوليو': 7,
      'أغسطس': 8,
      'اغسطس': 8,
      'سبتمبر': 9,
      'أكتوبر': 10,
      'اكتوبر': 10,
      'نوفمبر': 11,
      'ديسمبر': 12,
    };
    for (final entry in months.entries) {
      if (name.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static DateTime? _safeDate(int year, int month, int day) {
    // Normalize out-of-range months.
    var y = year;
    var m = month;
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    if (day < 1 || day > 31) return null;
    final candidate = DateTime(y, m, day);
    // DateTime silently rolls overflow — reject rolled dates (Feb 30…).
    if (candidate.month != m || candidate.day != day) return null;
    return candidate;
  }

  static (DateTime?, DateTime?) _extractDates(String query) {
    DateTime? departureDate;
    DateTime? returnDate;

    // Look for date patterns in the query
    for (final format in _dateFormats) {
      try {
        final formatter = DateFormat(format);
        // Simple pattern match - in production this would be more sophisticated
        final words = query.split(' ');
        for (int i = 0; i < words.length - 2; i++) {
          final candidate = '${words[i]} ${words[i + 1]} ${words[i + 2]}';
          try {
            final date = formatter.parseLoose(candidate);
            if (departureDate == null) {
              departureDate = date;
            } else {
              returnDate = date;
              break;
            }
          } catch (_) {
            // Skip invalid dates
          }
        }
      } catch (_) {
        continue;
      }
    }

    return (departureDate, returnDate);
  }

  static int? _extractPassengers(String lowerQuery) {
    final passengerPatterns = [
      RegExp(r'(\d+) passenger'),
      RegExp(r'(\d+) adult'),
      RegExp(r'لـ\s*(\d+)\s*أشخاص'),
      RegExp(r'for\s*(\d+)\s*people'),
      // US-2: "3 أشخاص" / "شخصين" / "2 شخص".
      RegExp(r'(\d+)\s*أشخاص'),
      RegExp(r'(\d+)\s*شخص'),
      RegExp(r'(\d+)\s*persons?'),
      RegExp(r'(\d+)\s*people'),
    ];

    for (final pattern in passengerPatterns) {
      final match = pattern.firstMatch(lowerQuery);
      if (match != null) {
        final count = int.tryParse(match.group(1)!);
        // US-2 §5: reject impossible counts safely.
        if (count == null || count < 1 || count > 9) continue;
        return count;
      }
    }

    // The dual form "شخصين" — exactly two people.
    if (lowerQuery.contains('شخصين') || lowerQuery.contains('اتنين')) {
      return 2;
    }

    return null;
  }

  static int? _extractNights(String lowerQuery) {
    final match = _nightsPattern.firstMatch(lowerQuery);
    if (match == null) return null;
    final nights = int.tryParse(match.group(1)!);
    // US-2 §5: plausible stays only.
    if (nights == null || nights < 1 || nights > 30) return null;
    return nights;
  }

  static int? _extractRooms(String lowerQuery) {
    final match = RegExp(r'(\d+)\s*(?:غرف|غرفة|rooms?)').firstMatch(lowerQuery);
    if (match == null) return null;
    final rooms = int.tryParse(match.group(1)!);
    if (rooms == null || rooms < 1 || rooms > 5) return null;
    return rooms;
  }

  static String? _detectBudgetBand(String lowerQuery) {
    if (_budgetLowKeywords.any((k) => lowerQuery.contains(k))) return 'low';
    if (_budgetHighKeywords.any((k) => lowerQuery.contains(k))) return 'high';
    if (_budgetMediumKeywords.any((k) => lowerQuery.contains(k))) {
      return 'medium';
    }
    return null;
  }

  static double? _extractStars(String lowerQuery) {
    final match = _starsPattern.firstMatch(lowerQuery);
    if (match == null) return null;
    final stars = double.tryParse(match.group(1)!);
    if (stars == null || stars < 1 || stars > 5) return null;
    return stars;
  }

  static List<String> _extractAmenities(String lowerQuery) {
    const vocabulary = <String, String>{
      'wifi': 'WiFi',
      'واي فاي': 'WiFi',
      'wifi free': 'WiFi',
      'pool': 'Pool',
      'مسبح': 'Pool',
      'حمام سباحة': 'Pool',
      'gym': 'Gym',
      'جيم': 'Gym',
      'breakfast': 'Breakfast',
      'فطار': 'Breakfast',
      'إفطار': 'Breakfast',
      'airport transfer': 'Airport transfer',
      'نقل مطار': 'Airport transfer',
      'قريب من المطار': 'Airport transfer',
      'airport': 'Airport transfer',
    };
    final found = <String>[];
    for (final entry in vocabulary.entries) {
      if (lowerQuery.contains(entry.key) && !found.contains(entry.value)) {
        found.add(entry.value);
      }
    }
    return found;
  }
}
