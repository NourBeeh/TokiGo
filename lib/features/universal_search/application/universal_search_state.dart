import 'package:flutter/foundation.dart';

import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/features/universal_search/domain/structured_travel_intent.dart';

/// Universal Search state machine (US-1 contract).///
/// The eight states of the Universal Search + AI experience. Transitions are
/// strictly validated — any move not in [UniversalSearchState.canGoTo] is
/// rejected by the controller, so widgets can never mutate the flow
/// ad-hoc. `AI_INTERPRETING` is deliberately NOT a state: AI
/// interpretation is a flag riding on top of SEARCHING.
enum UniversalSearchPhase {
  /// The Home surface with the collapsed search bar.
  closed,

  /// Container-transform flight from the Home pill to the full surface.
  opening,

  /// Surface open, query empty — recents, categories and AI ideas.
  active,

  /// Query non-empty — live suggestions streaming under the field.
  typing,

  /// A search/intent is executing — shimmer sections.
  searching,

  /// Direct search results rendered in place.
  results,

  /// AI-interpreted narrative + follow-up chips + product sections.
  aiResult,

  /// Reverse container-transform back into the Home pill.
  closing,
}

/// Immutable snapshot of the Universal Search surface owned by
/// [UniversalSearchController] — the single source of truth.
@immutable
class UniversalSearchState {
  const UniversalSearchState({
    this.phase = UniversalSearchPhase.closed,
    this.query = '',
    this.suggestions = const [],
    this.suggestionsLoading = false,
    this.recents = const [],
    this.structuredIntent,
    this.aiInterpreting = false,
    this.aiNarrative,
    this.resultSections = const [],
    this.selectedResultId,
    this.intentGaps = const [],
  });

  final UniversalSearchPhase phase;

  /// The live text in the field (and preserved across close/reopen).
  final String query;

  final List<String> suggestions;
  final bool suggestionsLoading;

  /// Persisted recent searches (submit-only updates, newest first).
  final List<String> recents;

  /// The structured travel intent extracted from a natural query, when the
  /// last submission was interpreted.
  final StructuredTravelIntent? structuredIntent;

  /// AI interpretation flag — rides on top of `searching`, never a phase.
  final bool aiInterpreting;

  /// One-line narrative shown above AI-interpreted results.
  final String? aiNarrative;

  /// Rendered product sections (direct or AI-interpreted results).
  final List<HomeSection> resultSections;

  /// The currently selected result id (booking hand-off).
  final String? selectedResultId;

  /// Missing pieces of the current intent — surfaced as question chips
  /// (US-2 §3): never invent facts, ask instead.
  final List<IntentGap> intentGaps;

  UniversalSearchState copyWith({
    UniversalSearchPhase? phase,
    String? query,
    List<String>? suggestions,
    bool? suggestionsLoading,
    List<String>? recents,
    StructuredTravelIntent? structuredIntent,
    bool? aiInterpreting,
    String? aiNarrative,
    List<HomeSection>? resultSections,
    String? selectedResultId,
    List<IntentGap>? intentGaps,
  }) {
    return UniversalSearchState(
      phase: phase ?? this.phase,
      query: query ?? this.query,
      suggestions: suggestions ?? this.suggestions,
      suggestionsLoading:
          suggestionsLoading ?? this.suggestionsLoading,
      recents: recents ?? this.recents,
      structuredIntent: structuredIntent ?? this.structuredIntent,
      aiInterpreting: aiInterpreting ?? this.aiInterpreting,
      aiNarrative: aiNarrative ?? this.aiNarrative,
      resultSections: resultSections ?? this.resultSections,
      selectedResultId: selectedResultId ?? this.selectedResultId,
      intentGaps: intentGaps ?? this.intentGaps,
    );
  }

  /// The allowed-transition table from the US-0 contract. Anything outside
  /// this table must be rejected.
  bool canGoTo(UniversalSearchPhase next) {
    return switch (phase) {
      UniversalSearchPhase.closed => next == UniversalSearchPhase.opening,
      // Reopening with a preserved query enters TYPING directly (US-1
      // STEP 8) — OPENING may hand off to either ACTIVE or TYPING.
      UniversalSearchPhase.opening =>
          next == UniversalSearchPhase.active ||
          next == UniversalSearchPhase.typing,
      UniversalSearchPhase.active => next == UniversalSearchPhase.typing ||
          next == UniversalSearchPhase.closing,
      UniversalSearchPhase.typing => next == UniversalSearchPhase.active ||
          next == UniversalSearchPhase.searching ||
          next == UniversalSearchPhase.closing,
      UniversalSearchPhase.searching => next == UniversalSearchPhase.results ||
          next == UniversalSearchPhase.aiResult ||
          next == UniversalSearchPhase.active,
      UniversalSearchPhase.results => next == UniversalSearchPhase.typing ||
          next == UniversalSearchPhase.searching ||
          next == UniversalSearchPhase.closing,
      UniversalSearchPhase.aiResult =>
          next == UniversalSearchPhase.searching ||
              next == UniversalSearchPhase.typing ||
              next == UniversalSearchPhase.closing,
      UniversalSearchPhase.closing => next == UniversalSearchPhase.closed,
    };
  }
}
