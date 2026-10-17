import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/search/flight_search_params.dart';
import 'package:tokigo/core/domain/models/search/hotel_search_params.dart';
import 'package:tokigo/core/domain/models/search/car_search_params.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';
import 'package:tokigo/features/ai/application/ai_providers.dart'
    show aiSuggestionsServiceProvider;
import 'package:tokigo/features/ai/domain/search_intent_parser.dart';
import 'package:tokigo/features/search/application/providers/search_providers.dart'
    show flightSearchControllerProvider;
import 'package:tokigo/features/search/application/providers/hotel_car_providers.dart'
    show hotelSearchControllerProvider, carSearchControllerProvider;
import 'package:tokigo/features/search/application/controllers/flight_search_controller.dart';
import 'package:tokigo/features/search/application/controllers/hotel_search_controller.dart';
import 'package:tokigo/features/search/application/controllers/car_search_controller.dart';
import 'package:tokigo/features/universal_search/application/universal_search_state.dart';
import 'package:tokigo/features/universal_search/data/offer_to_home_item_adapters.dart';
import 'package:tokigo/features/universal_search/domain/structured_travel_intent.dart';

/// Orchestrator of the Universal Search surface — the single source of
/// truth (US-1 STEP 3). Owns the state machine, query preservation,
/// recents, debounced suggestions and intent compilation. The actual
/// search business logic stays in the EXISTING flight/hotel/car
/// controllers — this class only orchestrates them.
///
/// Behavioral events (`hotel_search`) fire from inside the existing
/// controllers on success, exactly as in the vertical flows — Universal
/// Search never starves the Recommendation Engine.
class UniversalSearchController extends StateNotifier<UniversalSearchState> {
  UniversalSearchController({
    required this.suggestionsDelegate,
    required this.cache,
    required this.flightSearch,
    required this.hotelSearch,
    required this.carSearch,
  }) : super(const UniversalSearchState());

  final AiSuggestionsDelegate suggestionsDelegate;
  final OfflineCache cache;
  final FlightSearchController flightSearch;
  final HotelSearchController hotelSearch;
  final CarSearchController carSearch;

  static const String _kRecentPrefix = 'ai_search_recent/';
  static const String _kPreservedQueryKey = 'universal_search/preserved_query';
  static const int _kRecentLimit = 8;
  static const Duration _kDebounce = Duration(milliseconds: 400);

  /// Public read for wiring/pages that need the current snapshot before
  /// watching the provider (e.g. seeding the field on mount).
  UniversalSearchState get currentState => state;

  /// Restores the query preserved by the previous session (US-1 STEP 8).
  /// Returns empty when none exists. Called by the page on mount BEFORE
  /// `open()` so the machine can reopen into TYPING.
  Future<String> restorePreservedQuery() async {
    try {
      final entry = await cache.read(_kPreservedQueryKey);
      final text = entry?['text'] as String?;
      return text ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Persists the query so the next open can resume (called on every query
  /// change — a tiny single-key write, and on close the last one stands).
  Future<void> preserveQuery(String text) async {
    try {
      await cache.write(
        _kPreservedQueryKey,
        <String, dynamic>{'text': text},
      );
    } catch (_) {
      // Best-effort persistence only.
    }
  }

  Timer? _debounce;
  int _suggestVersion = 0;
  int _searchVersion = 0;

  // ---------------------------------------------------------------------------
  // Phase transitions — the only door into the state machine.
  // ---------------------------------------------------------------------------

  void _goTo(UniversalSearchPhase next) {
    if (state.phase == next) return;
    if (!state.canGoTo(next)) {
      assert(
        false,
        'Forbidden transition ${state.phase.name} -> ${next.name}',
      );
      return;
    }
    state = state.copyWith(phase: next);
  }

  /// The Home pill was tapped — the container-transform opening begins.
  void open() => _goTo(UniversalSearchPhase.opening);

  /// The route mounted. Reopening with a preserved query enters TYPING
  /// directly (US-1 STEP 8); a fresh surface enters ACTIVE.
  void surfaceReady() {
    if (state.phase != UniversalSearchPhase.opening) return;
    final hasQuery = state.query.trim().isNotEmpty;
    _goTo(hasQuery ? UniversalSearchPhase.typing : UniversalSearchPhase.active);
    if (hasQuery) {
      onQueryChanged(state.query);
    }
  }

  /// Begin the closing flight. The query is PRESERVED — never cleared.
  void close() {
    _debounce?.cancel();
    if (state.canGoTo(UniversalSearchPhase.closing)) {
      _goTo(UniversalSearchPhase.closing);
    }
  }

  /// The route fully exited — back to CLOSED.
  void surfaceClosed() {
    if (state.phase == UniversalSearchPhase.closing) {
      _goTo(UniversalSearchPhase.closed);
    }
  }

  // ---------------------------------------------------------------------------
  // Query + suggestions (debounced, version-guarded).
  // ---------------------------------------------------------------------------

  void onQueryChanged(String text) {
    final query = text.trim();
    switch (state.phase) {
      case UniversalSearchPhase.active:
        if (query.isEmpty) {
          state = state.copyWith(query: text);
          return;
        }
        _goTo(UniversalSearchPhase.typing);
      case UniversalSearchPhase.typing:
        if (query.isEmpty) {
          _goTo(UniversalSearchPhase.active);
        }
      case UniversalSearchPhase.results:
      case UniversalSearchPhase.aiResult:
        // Editing the field always leaves the results view first.
        _goTo(UniversalSearchPhase.typing);
      case UniversalSearchPhase.closed:
      case UniversalSearchPhase.opening:
      case UniversalSearchPhase.searching:
      case UniversalSearchPhase.closing:
        state = state.copyWith(query: text);
        return;
    }
    state = state.copyWith(query: text);
    preserveQuery(text); // US-1 STEP 8 — the query outlives the surface.

    _debounce?.cancel();
    if (query.length < 2) {
      state = state.copyWith(
        suggestions: const [],
        suggestionsLoading: false,
      );
      return;
    }
    state = state.copyWith(suggestionsLoading: true);
    _debounce = Timer(_kDebounce, () => _fetchSuggestions(query));
  }

  Future<void> _fetchSuggestions(String query) async {
    final version = ++_suggestVersion;
    try {
      final suggestions = await suggestionsDelegate.suggest(query);
      if (version != _suggestVersion) return;
      state = state.copyWith(
        suggestionsLoading: false,
        suggestions: suggestions,
      );
    } catch (_) {
      if (version != _suggestVersion) return;
      state = state.copyWith(
        suggestionsLoading: false,
        suggestions: const [], // the page layer renders the local fallback
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Submission — SearchIntentParser door (US-1 STEP 14).
  // ---------------------------------------------------------------------------

  /// Submit the current query. A query that compiles into a COMPLETE
  /// intent runs through the EXISTING vertical controllers; a valid but
  /// INCOMPLETE intent surfaces its gaps as question chips (US-2 §3 —
  /// never invent facts); anything else keeps the established AI sheet
  /// flow (page layer renders it).
  Future<void> submit() async {
    final text = state.query.trim();
    if (text.isEmpty) return;
    _debounce?.cancel();

    final parsed = SearchIntentParser.parse(text);
    if (parsed.isValid) {
      final intent = _intentFromParsed(parsed);
      final gaps = intent.missingFields();
      if (gaps.isNotEmpty) {
        // US-2 §3: ask, don't invent. The intent stays parked on the
        // state; filling a gap resumes the flow.
        state = state.copyWith(
          structuredIntent: intent,
          intentGaps: gaps,
          aiInterpreting: false,
        );
        return;
      }
      await _runIntent(intent);
    } else {
      // AI resolution contract (US-2 §4): whatever the AI layer returns
      // must be converted into a StructuredTravelIntent before it may
      // execute — raw LLM output never controls navigation or provider
      // APIs. The AI sheet flow renders sections; intent conversion hooks
      // in aiResultsReady when a structured payload is present.
      // US-4: the AI path is now the CONTEXTUAL ASSISTANT layer — it may
      // answer with a narrative + real sections, but it can never trap the
      // user: aiResultsFailed degrades to deterministic search below.
      _goTo(UniversalSearchPhase.searching);
      state = state.copyWith(aiInterpreting: true, aiNarrative: null);
    }
  }

  /// Compiles the parser result into the typed intent (US-2 §1).
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

  /// A gap chip was answered (US-2 §3): patch the parked intent and
  /// resume — search only once every required field stands on facts.
  Future<void> fillGap(StructuredTravelIntent patched) async {
    final gaps = patched.missingFields();
    state = state.copyWith(
      structuredIntent: patched,
      intentGaps: gaps,
    );
    if (gaps.isEmpty) {
      await _runIntent(patched);
    }
  }

  Future<void> _runIntent(StructuredTravelIntent intent) async {
    final version = ++_searchVersion;
    _goTo(UniversalSearchPhase.searching);
    state = state.copyWith(
      aiInterpreting: false,
      structuredIntent: intent,
      intentGaps: const [],
    );

    final sections = await _executeIntent(intent);
    if (version != _searchVersion) return;

    if (sections.isEmpty) {
      state = state.copyWith(resultSections: const []);
      _goTo(UniversalSearchPhase.aiResult);
      return;
    }
    state = state.copyWith(resultSections: sections);
    _goTo(UniversalSearchPhase.results);
  }

  /// Runs an intent through the EXISTING controllers and adapts the offers
  /// into renderable Home sections. `hotel_search` behavioral events fire
  /// from inside the hotel controller on success — same as the vertical
  /// flows, no duplicate event schema.
  ///
  /// US-2: every mapped value comes from the intent or the vertical's own
  /// documented convention — the SAME defaults the vertical forms present
  /// (flight/hotel: today + 7d, car: today + 1d). The budget band
  /// translates to CONCRETE param windows here (never raw LLM numbers
  /// reaching providers).
  Future<List<HomeSection>> _executeIntent(StructuredTravelIntent intent) async {
    switch (intent.type) {
      case 'flight':
        // Flights require both endpoints — guaranteed non-null by
        // `missingFields()` gating in submit/fillGap. The departure date
        // falls back to the vertical form's own default (+7d).
        await flightSearch.search(FlightSearchParams(
          origin: intent.origin!,
          destination: intent.destination!,
          departureDate: intent.date ?? _verticalDefaultStart(),
          returnDate: intent.returnDate,
          adults: intent.passengers ?? 1,
        ));
        return offersToHomeSections(flightSearch.state.results);
      case 'hotel':
        final checkIn = intent.date ?? _verticalDefaultStart();
        await hotelSearch.search(HotelSearchParams(
          destination: intent.destination!,
          checkIn: checkIn,
          checkOut: intent.effectiveEndDate(checkIn),
          rooms: intent.rooms ?? 1,
          adults: intent.passengers ?? 2,
          minRating: _minRatingFor(intent),
          maxPrice: _maxPriceFor(intent),
          minPrice: _minPriceFor(intent),
          amenities: intent.amenities,
        ));
        return offersToHomeSections(hotelSearch.state.results);
      case 'car':
        // The car form's own convention: pickup tomorrow, +3-day span.
        final pickup = intent.date ?? DateTime.now().add(const Duration(days: 1));
        await carSearch.search(CarSearchParams(
          pickupLocation: intent.origin ?? intent.destination!,
          dropoffLocation: intent.destination!,
          pickupDateTime: pickup,
          dropoffDateTime: intent.effectiveEndDate(pickup, defaultNights: 3),
        ));
        return offersToHomeSections(carSearch.state.results);
      default:
        return const <HomeSection>[];
    }
  }

  /// The flight/hotel vertical forms' shared default start (today + 7d)
  /// — their own documented convention, mirrored exactly.
  DateTime _verticalDefaultStart() =>
      DateTime.now().add(const Duration(days: 7));

  /// Budget bands to concrete windows (US-2 §4): the grammar says the
  /// BAND, execution decides the numbers. Bands are conservative caps.
  double? _maxPriceFor(StructuredTravelIntent intent) {
    return switch (intent.budget) {
      IntentBudgetBand.low => 120,
      IntentBudgetBand.medium => 300,
      _ => null,
    };
  }

  double? _minPriceFor(StructuredTravelIntent intent) {
    return intent.budget == IntentBudgetBand.high ? 200 : null;
  }

  double? _minRatingFor(StructuredTravelIntent intent) {
    if (intent.minStars != null) return intent.minStars;
    return intent.budget == IntentBudgetBand.high ? 4.0 : null;
  }

  /// The AI flow (page layer) landed with product sections.
  void aiResultsReady(List<HomeSection> sections, String? narrative) {
    if (state.phase != UniversalSearchPhase.searching) return;
    state = state.copyWith(
      aiInterpreting: false,
      aiNarrative: narrative,
      resultSections: sections,
    );
    _goTo(UniversalSearchPhase.aiResult);
  }

  /// The AI flow failed — US-4: AI must NEVER block search.
  ///
  /// Degrades to the DETERMINISTIC path: the query is retried through the
  /// parser with a best-effort service inference; when that yields a
  /// complete intent it executes through the real controllers, and the
  /// user lands on results (or the empty state) exactly like a typed
  /// search. When even the fallback cannot compile an intent, the surface
  /// shows the empty-state with the edit affordance — never a trap.
  void aiResultsFailed() {
    if (state.phase != UniversalSearchPhase.searching) return;
    state = state.copyWith(aiInterpreting: false, aiNarrative: null);

    // US-4 deterministic fallback: try the query once more as a plain
    // location/service search. This reuses the SAME parser door as a
    // typed query — no parallel interpretation logic.
    final text = state.query.trim();
    final fallbackIntent = _deterministicFallbackIntent(text);
    if (fallbackIntent != null && fallbackIntent.isComplete) {
      // Fire-and-forget by design: _runIntent owns the phase machine and
      // versioning; the page rebuilds on every state emission.
      _runIntent(fallbackIntent);
      return;
    }
    _goTo(UniversalSearchPhase.aiResult);
  }

  /// Best-effort deterministic interpretation for the AI-failure fallback
  /// (US-4). The parser already returned invalid for this text — the only
  /// remaining honest signal is a NAMED PLACE the user typed. We extract
  /// it through the parser's own place dictionary and default to the
  /// HOTEL vertical (the traveler's most common need), never inventing
  /// dates or budgets.
  StructuredTravelIntent? _deterministicFallbackIntent(String text) {
    if (text.isEmpty) return null;
    final parsed = SearchIntentParser.parse(text);
    // The parser DID find a service but the intent was incomplete → the
    // gaps flow already owns that case; do not duplicate it here.
    if (parsed.isValid) return null;
    final place = _lonePlaceIn(text);
    if (place == null) return null;
    return StructuredTravelIntent(
      type: 'hotel',
      destination: place,
    );
  }

  /// Extracts a lone dictionary place from a service-less query — reuses
  /// the parser's own `_extractInPlace` behavior by probing common
  /// prepositions. Pure and deterministic.
  String? _lonePlaceIn(String text) {
    final lower = text.toLowerCase();
    // The parser's place dictionary resolves "in/at/في <place>" — reuse
    // its full public parse on a normalized probe string.
    for (final probe in <String>['in ', 'at ', 'في ']) {
      final idx = lower.indexOf(probe);
      if (idx >= 0) {
        final candidate = lower.substring(idx + probe.length).trim();
        if (candidate.isNotEmpty) {
          // A dictionary hit re-parses into a valid hotel intent — take it.
          final reparsed = SearchIntentParser.parse('hotel in $candidate');
          if (reparsed.isValid && reparsed.destination != null) {
            return reparsed.destination;
          }
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Follow-ups (US-1 STEP 20 — only the two intent-patchable ones).
  // ---------------------------------------------------------------------------

  Future<void> applyFollowUp(FollowUpAction action) async {
    final intent = state.structuredIntent;
    if (intent == null) return;
    final version = ++_searchVersion;

    StructuredTravelIntent patched;
    switch (action) {
      case FollowUpAction.cheaper:
        // Patch the BAND, not a number (US-2 §4) — execution maps it.
        patched = intent.copyWith(budget: IntentBudgetBand.low);
      case FollowUpAction.morePremium:
        patched = intent.copyWith(budget: IntentBudgetBand.high);
      case FollowUpAction.changeDates:
        // Surface the date question instead of guessing (US-2 §3).
        state = state.copyWith(intentGaps: <IntentGap>[IntentGap.dates]);
        return;
      case FollowUpAction.twoPeople:
        patched = intent.copyWith(passengers: 2);
      case FollowUpAction.nearAirport:
        patched = intent.copyWith(
          amenities: <String>[...intent.amenities, 'Airport transfer'],
        );
      case FollowUpAction.compare:
        // US-4 — contract only: comparison selection state is the US-6
        // surface's concern. The intent is untouched (nothing to patch),
        // the phase stays on results — the chip's presence in the UI is
        // the contract; US-6 builds the comparison view on this signal.
        return;
    }

    _goTo(UniversalSearchPhase.searching);
    state = state.copyWith(structuredIntent: patched);

    final sections = await _executeIntent(patched);
    if (version != _searchVersion) return;
    state = state.copyWith(resultSections: sections);
    _goTo(sections.isEmpty
        ? UniversalSearchPhase.aiResult
        : UniversalSearchPhase.results);
  }

  /// The change-dates chip answered with concrete dates (US-2 §8).
  Future<void> applyDateRange(DateTime start, DateTime? end) async {
    final intent = state.structuredIntent;
    if (intent == null) return;
    final patched = intent.copyWith(date: start, returnDate: end);
    state = state.copyWith(
      structuredIntent: patched,
      intentGaps: const [],
    );
    await _runIntent(patched);
  }

  // ---------------------------------------------------------------------------
  // Recents — submit-only updates (US-1 STEP 9).
  // ---------------------------------------------------------------------------

  Future<void> loadRecents() async {
    final recents = <String>[];
    try {
      for (var i = 0; i < _kRecentLimit; i++) {
        final entry = await cache.read('$_kRecentPrefix$i');
        final text = entry?['text'] as String?;
        if (text == null || text.trim().isEmpty) break;
        recents.add(text);
      }
    } catch (_) {
      // Unreadable history must never block the search surface.
    }
    state = state.copyWith(recents: recents);
  }

  /// Recording a recent is allowed ONLY on submit.
  Future<void> recordRecent(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;
    final updated = <String>[
      trimmed,
      ...state.recents.where((e) => e != trimmed),
    ].take(_kRecentLimit).toList();
    state = state.copyWith(recents: updated);
    try {
      for (var i = 0; i < _kRecentLimit; i++) {
        final key = '$_kRecentPrefix$i';
        if (i < updated.length) {
          await cache.write(key, <String, dynamic>{'text': updated[i]});
        } else if (await cache.contains(key)) {
          await cache.delete(key);
        }
      }
    } catch (_) {
      // Best-effort persistence only.
    }
  }

  Future<void> removeRecentAt(int index) async {
    final updated = <String>[...state.recents]..removeAt(index);
    state = state.copyWith(recents: updated);
    try {
      for (var i = 0; i < _kRecentLimit; i++) {
        final key = '$_kRecentPrefix$i';
        if (i < updated.length) {
          await cache.write(key, <String, dynamic>{'text': updated[i]});
        } else if (await cache.contains(key)) {
          await cache.delete(key);
        }
      }
    } catch (_) {
      // Best-effort persistence only.
    }
  }

  Future<void> clearRecents() async {
    state = state.copyWith(recents: const []);
    try {
      final keys = await cache.keys();
      for (final key in keys) {
        if (key.startsWith(_kRecentPrefix)) {
          await cache.delete(key);
        }
      }
    } catch (_) {
      // Best-effort persistence only.
    }
  }

  // ---------------------------------------------------------------------------
  // Selection (booking hand-off stays with SelectedOffer in the page).
  // ---------------------------------------------------------------------------

  void selectResult(String id) {
    state = state.copyWith(selectedResultId: id);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

/// Delegate over `aiSuggestionsServiceProvider` — kept abstract so tests
/// stub typeahead without HTTP.
abstract class AiSuggestionsDelegate {
  Future<List<String>> suggest(String query);
}

/// Riverpod wiring (US-1): real delegates over the existing services and
/// controllers. Nothing is re-implemented here.
///
/// `autoDispose` keeps the surface state route-scoped: a fresh machine is
/// born on every push of `/smart-search` (query preservation across
/// close/reopen is carried by the controller's recent ring + the field
/// text itself survives through the retained provider while the app
/// lives) — the page drives OPENING -> ACTIVE/TYPING on mount.
final universalSearchControllerProvider = StateNotifierProvider.autoDispose<
    UniversalSearchController, UniversalSearchState>((ref) {
  return UniversalSearchController(
    suggestionsDelegate: _AiApiSuggestionsDelegate(
      ref.watch(aiSuggestionsServiceProvider),
    ),
    cache: ref.watch(offlineCacheProvider),
    flightSearch: ref.watch(flightSearchControllerProvider.notifier),
    hotelSearch: ref.watch(hotelSearchControllerProvider.notifier),
    carSearch: ref.watch(carSearchControllerProvider.notifier),
  );
});

class _AiApiSuggestionsDelegate implements AiSuggestionsDelegate {
  _AiApiSuggestionsDelegate(this._service);

  final dynamic _service;

  @override
  Future<List<String>> suggest(String query) async {
    return _service.suggest(query) as Future<List<String>>;
  }
}
