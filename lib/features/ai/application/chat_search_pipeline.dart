import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/search/car_search_params.dart';
import 'package:tokigo/core/domain/models/search/flight_search_params.dart';
import 'package:tokigo/core/domain/models/search/hotel_search_params.dart';
import 'package:tokigo/features/ai/domain/search_intent_parser.dart';
import 'package:tokigo/features/search/application/controllers/car_search_controller.dart';
import 'package:tokigo/features/search/application/controllers/flight_search_controller.dart';
import 'package:tokigo/features/search/application/controllers/hotel_search_controller.dart';
import 'package:tokigo/features/universal_search/data/offer_to_home_item_adapters.dart';
import 'package:tokigo/features/universal_search/domain/structured_travel_intent.dart';

/// The result of running a natural query through the deterministic pipeline.
class ChatSearchOutcome {
  const ChatSearchOutcome({
    required this.hasIntent,
    required this.complete,
    this.sections = const <HomeSection>[],
    this.type,
  });

  /// The parser recognized a service (flight/hotel/car/package).
  final bool hasIntent;

  /// Every required field was present and the search actually ran.
  final bool complete;

  /// Renderable product sections (only when [complete]).
  final List<HomeSection> sections;

  /// The resolved vertical (`flight`/`hotel`/`car`), when any.
  final String? type;
}

/// Runs a natural-language query through the EXISTING vertical search
/// controllers — the same deterministic path the Universal Search used to
/// own, now feeding the unified chat-first surface.
///
/// Nothing is re-implemented: `SearchIntentParser` extracts the intent, the
/// existing flight/hotel/car controllers execute it, and
/// [OfferToHomeItemAdapters] maps the offers onto the shared card system.
class ChatSearchPipeline {
  ChatSearchPipeline({
    required this.flightSearch,
    required this.hotelSearch,
    required this.carSearch,
  });

  final FlightSearchController flightSearch;
  final HotelSearchController hotelSearch;
  final CarSearchController carSearch;

  Future<ChatSearchOutcome> run(
    String query, {
    String? suggestedOrigin,
    String? preferredDestination,
    double? preferredBudgetMin,
    double? preferredBudgetMax,
  }) async {
    final parsed = SearchIntentParser.parse(query);
    if (!parsed.isValid) {
      return const ChatSearchOutcome(hasIntent: false, complete: false);
    }
    var intent = _intentFromParsed(parsed);
    if (intent.type == 'flight' &&
        (intent.origin == null || intent.origin!.trim().isEmpty) &&
        suggestedOrigin != null &&
        suggestedOrigin.trim().isNotEmpty) {
      intent = intent.copyWith(origin: suggestedOrigin.trim().toUpperCase());
    }
    if (intent.type == 'hotel') {
      final destination = intent.destination ?? preferredDestination;
      final min = preferredBudgetMin != null && preferredBudgetMin >= 0
          ? preferredBudgetMin
          : null;
      final max = preferredBudgetMax != null && preferredBudgetMax > 0
          ? preferredBudgetMax
          : null;
      if (destination != null || min != null || max != null) {
        intent = intent.copyWith(
          destination: destination,
          preferredBudgetMin: min,
          preferredBudgetMax: max,
        );
      }
    }
    if (intent.missingFields().isNotEmpty) {
      return ChatSearchOutcome(
        hasIntent: true,
        complete: false,
        type: intent.type,
      );
    }
    try {
      final offers = await _fetchOffers(intent);
      final sections = offersToHomeSections(offers);
      return ChatSearchOutcome(
        hasIntent: true,
        complete: true,
        sections: sections,
        type: intent.type,
      );
    } catch (_) {
      // A provider failure never crashes the chat — the caller falls back to
      // the AI layer / empty state.
      return ChatSearchOutcome(
        hasIntent: true,
        complete: false,
        type: intent.type,
      );
    }
  }

  StructuredTravelIntent _intentFromParsed(ParsedSearchIntent parsed) {
    return StructuredTravelIntent(
      type: parsed.service!,
      origin: parsed.origin,
      destination: parsed.destination,
      date: parsed.date,
      returnDate: parsed.returnDate,
      durationNights: parsed.durationNights,
      passengers: parsed.passengers,
      rooms: parsed.rooms,
      budget: switch (parsed.budgetBand) {
        'low' => IntentBudgetBand.low,
        'medium' => IntentBudgetBand.medium,
        'high' => IntentBudgetBand.high,
        _ => IntentBudgetBand.none,
      },
      minStars: parsed.minStars,
      amenities: parsed.amenities,
    );
  }

  Future<List<dynamic>> _fetchOffers(StructuredTravelIntent intent) async {
    switch (intent.type) {
      case 'flight':
        await flightSearch.search(
          FlightSearchParams(
            origin: intent.origin!,
            destination: intent.destination!,
            departureDate: intent.date ?? _verticalDefaultStart(),
            returnDate: intent.returnDate,
            adults: intent.passengers ?? 1,
          ),
        );
        return flightSearch.results;
      case 'hotel':
        final checkIn = intent.date ?? _verticalDefaultStart();
        await hotelSearch.search(
          HotelSearchParams(
            destination: intent.destination!,
            checkIn: checkIn,
            checkOut: intent.effectiveEndDate(checkIn),
            rooms: intent.rooms ?? 1,
            adults: intent.passengers ?? 2,
            minRating: _minRatingFor(intent),
            maxPrice: _maxPriceFor(intent),
            minPrice: _minPriceFor(intent),
            amenities: intent.amenities,
          ),
        );
        final minPrice = _minPriceFor(intent);
        final maxPrice = _maxPriceFor(intent);
        return hotelSearch.results.where((offer) {
          final price = offer.price;
          if (minPrice != null && price < minPrice) return false;
          if (maxPrice != null && price > maxPrice) return false;
          return true;
        }).toList();
      case 'car':
        final pickup =
            intent.date ?? DateTime.now().add(const Duration(days: 1));
        await carSearch.search(
          CarSearchParams(
            pickupLocation: intent.origin ?? intent.destination!,
            dropoffLocation: intent.destination!,
            pickupDateTime: pickup,
            dropoffDateTime: intent.effectiveEndDate(pickup, defaultNights: 3),
          ),
        );
        return carSearch.results;
      default:
        return const <dynamic>[];
    }
  }

  DateTime _verticalDefaultStart() =>
      DateTime.now().add(const Duration(days: 7));

  double? _maxPriceFor(StructuredTravelIntent intent) {
    if (intent.preferredBudgetMax != null) return intent.preferredBudgetMax;
    return switch (intent.budget) {
      IntentBudgetBand.low => 120,
      IntentBudgetBand.medium => 300,
      _ => null,
    };
  }

  double? _minPriceFor(StructuredTravelIntent intent) {
    if (intent.preferredBudgetMin != null) return intent.preferredBudgetMin;
    return intent.budget == IntentBudgetBand.high ? 200 : null;
  }

  double? _minRatingFor(StructuredTravelIntent intent) {
    if (intent.minStars != null) return intent.minStars;
    return intent.budget == IntentBudgetBand.high ? 4.0 : null;
  }
}
