import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/features/ai/application/ai_state.dart';
import 'package:tokigo/features/ai/domain/ai_query_context.dart';
import 'package:tokigo/features/ai/presentation/widgets/ai_bottom_sheet.dart'
    show aiSheetControllerProvider;
import 'package:tokigo/features/universal_search/application/universal_search_controller.dart';
import 'package:tokigo/features/universal_search/application/universal_search_state.dart';
import 'package:tokigo/features/universal_search/application/voice_search_providers.dart';
import 'package:tokigo/features/universal_search/application/voice_search_state.dart';
import 'package:tokigo/features/universal_search/presentation/widgets/universal_search_widgets.dart';

/// The Universal Search + AI surface (US-1) — evolved from the v1 smart
/// search page into the full US-0 contract: a state-machine-driven
/// full-screen search experience with recents, categories, live
/// suggestions, structured-intent results rendered through the existing
/// card system, AI narrative results and intent-patch follow-ups.
///
/// The controller owns ALL state — this page is a pure renderer:
/// recents, suggestions, query preservation and phases all come from
/// `universalSearchControllerProvider`.
class UniversalSearchPage extends ConsumerStatefulWidget {
  const UniversalSearchPage({super.key});

  @override
  ConsumerState<UniversalSearchPage> createState() =>
      _UniversalSearchPageState();
}

class _UniversalSearchPageState extends ConsumerState<UniversalSearchPage> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  /// US-4 — hard ceiling on the AI-interpreting SEARCHING phase. The AI
  /// layer may hang (provider stall, network black hole) far past a usable
  /// wait; the search surface degrades to the deterministic path instead
  /// of spinning forever. 20s is the practical UX ceiling for a search
  /// surface — far below the backend's 90s provider budget, which is the
  /// right trade for THIS surface (the full AI chat page keeps its own
  /// long budget).
  static const Duration aiInterpretingTimeout = Duration(seconds: 20);
  Timer? _aiTimeoutTimer;

  @override
  void initState() {
    super.initState();
    final controller =
        ref.read(universalSearchControllerProvider.notifier);
    // US-3 — wire the transcription bridge BEFORE any session can start:
    // every voice chunk lands in the SAME query field, whose own listener
    // feeds `onQueryChanged` (single intake, no parallel voice state).
    ref
        .read(voiceSearchControllerProvider.notifier)
        .onTranscription = _onVoiceTranscription;
    // The route scope owns the OPENING phase: a fresh autoDispose machine
    // is born on every push of /smart-search. First restore the preserved
    // query (US-1 STEP 8) — if present, the machine reopens into TYPING.
    controller
        .restorePreservedQuery()
        .then((preserved) {
      if (!mounted) return;
      if (preserved.isNotEmpty && controller.currentState.query.isEmpty) {
        controller.onQueryChanged(preserved);
      }
      _seedFieldAndOpen(controller);
    });
  }

  void _seedFieldAndOpen(UniversalSearchController controller) {
    controller.open();
    _inputController.text = controller.currentState.query;
    _inputController.addListener(_onFieldChanged);
    controller.surfaceReady();
    controller.loadRecents();
    // Focus together with the hero flight departure: the caret and the
    // keyboard rise while the container is still morphing — the instant
    // responsiveness of the native search experiences (US-1 STEP 6).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _aiTimeoutTimer?.cancel();
    _inputController.removeListener(_onFieldChanged);
    _inputController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    ref
        .read(universalSearchControllerProvider.notifier)
        .onQueryChanged(_inputController.text);
  }

  void _submit() {
    final controller =
        ref.read(universalSearchControllerProvider.notifier);
    final text = controller.currentState.query.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _focusNode.unfocus();
    // Recents update ONLY on submit (US-1 STEP 9) — typing never records.
    controller.recordRecent(text);

    // The search box hands the query to the AI chat: the user types here
    // and presses send, and the same text lands already in the chat field.
    // Product results are a separate feature for the future.
    final query = text;
    if (query.isNotEmpty) {
      context.push('/ai-chat', extra: query);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _applySuggestion(String suggestion) {
    _inputController.text = suggestion;
    _inputController.selection = TextSelection.collapsed(
      offset: suggestion.length,
    );
    _submit();
  }

  // ── US-3 — voice search wiring ──────────────────────────────────────────
  // The transcription enters the SAME query pipeline: the field is the
  // single source of truth, `onQueryChanged` is the single intake, and no
  // parallel voice-query state exists (spec).

  void _onVoiceTranscription(String text, bool isFinal) {
    if (!mounted) return;
    _inputController.text = text;
    _inputController.selection =
        TextSelection.collapsed(offset: text.length);
    // Every partial drives the same TYPING phase (suggestions react live);
    // only the FINAL chunk restores the caret for review — the user
    // submits normally, no auto-search (spec).
    if (isFinal) {
      _focusNode.requestFocus();
    }
  }

  Future<void> _onMicTap() async {
    final voice = ref.read(voiceSearchControllerProvider.notifier);
    final isLive =
        ref.read(voiceSearchControllerProvider).status ==
            VoiceSearchStatus.listening;
    if (isLive) {
      await voice.stopSession();
      if (mounted) _focusNode.requestFocus();
      return;
    }
    HapticFeedback.lightImpact();
    _focusNode.unfocus();
    await voice.startSession();
  }

  void _clearInput() {
    _inputController.clear();
    _focusNode.requestFocus();
  }

  /// Closing always preserves the query (US-1 STEP 7/8): the field keeps
  /// its text — the controller state is the survival mechanism.
  void _close() {
    final controller = ref.read(universalSearchControllerProvider.notifier);
    controller.close();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(universalSearchControllerProvider);
    // US-3 — the mic session state, and the transcription bridge wired to
    // the SAME query pipeline (the provider's default bridge is a no-op;
    // the page overrides it through the listen below by directly writing
    // to the field, whose listener feeds onQueryChanged).
    final voiceState = ref.watch(voiceSearchControllerProvider);

    // The AI flow rides the established shared sheet controller (keyed by
    // prompt). When it lands, its sections are handed to the universal
    // controller — the single source of truth for rendering (US-1 STEP 19).
    final aiInterpreting =
        state.phase == UniversalSearchPhase.searching && state.aiInterpreting;
    if (aiInterpreting) {
      // US-4 — the timeout guard: arm once per SEARCHING stretch, cancel
      // the moment the phase resolves. A stalled AI layer degrades to the
      // deterministic fallback instead of spinning forever.
      _aiTimeoutTimer ??= Timer(aiInterpretingTimeout, () {
        if (!mounted) return;
        final current =
            ref.read(universalSearchControllerProvider);
        if (current.phase == UniversalSearchPhase.searching &&
            current.aiInterpreting) {
          ref
              .read(universalSearchControllerProvider.notifier)
              .aiResultsFailed();
        }
      });
    } else {
      _aiTimeoutTimer?.cancel();
      _aiTimeoutTimer = null;
    }
    if (aiInterpreting) {
      final prompt = state.query.trim();
      // US-4 — SAFE STRUCTURED CONTEXT: the AI layer receives only the
      // route + surface identifier — never tokens, credentials, private
      // backend data, or unnecessary personal information (spec).
      final args = (
        prompt: prompt,
        context: const AiQueryContext(route: 'smart-search'),
      );
      final aiState = ref.watch(aiSheetControllerProvider(args));
      final notifier =
          ref.read(universalSearchControllerProvider.notifier);
      switch (aiState.status) {
        case AiStatus.success:
          notifier.aiResultsReady(
            aiState.sections,
            aiState.responseText,
          );
        case AiStatus.error:
        case AiStatus.empty:
          notifier.aiResultsFailed();
        case AiStatus.loading:
        case AiStatus.idle:
          break;
      }
    }

    return PopScope(
      // Keyboard-first back (US-1 STEP 22): while the field holds focus,
      // back dismisses the keyboard only; the second back closes.
      canPop: !_focusNode.hasFocus,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _focusNode.unfocus();
        } else {
          ref
              .read(universalSearchControllerProvider.notifier)
              .surfaceClosed();
        }
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              UniversalSearchHeader(
                controller: _inputController,
                focusNode: _focusNode,
                hasText: state.query.trim().isNotEmpty,
                onBack: _close,
                onClear: _clearInput,
                onSubmit: _submit,
                voiceState: voiceState,
                onMicTap: _onMicTap,
              ),
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
              Expanded(child: _buildBody(state)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(UniversalSearchState state) {
    // US-2 §3: an incomplete-but-valid intent parks with question chips —
    // visible in every non-searching phase while gaps remain.
    if (state.intentGaps.isNotEmpty &&
        state.phase != UniversalSearchPhase.searching) {
      return UniversalSearchGapsBody(
        state: state,
        onGapAnswered: (patched) => ref
            .read(universalSearchControllerProvider.notifier)
            .fillGap(patched),
      );
    }
    switch (state.phase) {
      case UniversalSearchPhase.active:
      case UniversalSearchPhase.typing:
      case UniversalSearchPhase.opening:
        return UniversalSearchSuggestionsBody(
          state: state,
          onSuggestionTap: _applySuggestion,
          onRecentTap: _applySuggestion,
          onRecentDismiss: (index) => ref
              .read(universalSearchControllerProvider.notifier)
              .removeRecentAt(index),
          onClearRecents: () => ref
              .read(universalSearchControllerProvider.notifier)
              .clearRecents(),
          onCategoryTap: (route) {
            // Category chips leave Universal Search to the vertical page —
            // an explicit exit, never a search request (US-1 STEP 11).
            context.go(route);
          },
        );
      case UniversalSearchPhase.searching:
        return const UniversalSearchLoadingBody(aiInterpreting: false);
      case UniversalSearchPhase.results:
      case UniversalSearchPhase.aiResult:
        return UniversalSearchResultsBody(
          state: state,
          scrollController: _scrollController,
          onEditQuery: () {
            _focusNode.requestFocus();
          },
          onFollowUp: (action) => ref
              .read(universalSearchControllerProvider.notifier)
              .applyFollowUp(action),
          onRetry: () => _submit(),
        );
      case UniversalSearchPhase.closed:
      case UniversalSearchPhase.closing:
        return const SizedBox.shrink();
    }
  }
}
