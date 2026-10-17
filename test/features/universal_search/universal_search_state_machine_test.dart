import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/features/universal_search/application/universal_search_state.dart';

/// The US-0 contract's transition table — every allowed move passes and
/// every forbidden move is rejected by `canGoTo` (US-1 STEP 26).
void main() {
  UniversalSearchState at(UniversalSearchPhase phase) =>
      UniversalSearchState(phase: phase);

  group('allowed transitions', () {
    test('CLOSED -> OPENING', () {
      expect(at(UniversalSearchPhase.closed).canGoTo(UniversalSearchPhase.opening), isTrue);
    });

    test('OPENING -> ACTIVE', () {
      expect(at(UniversalSearchPhase.opening).canGoTo(UniversalSearchPhase.active), isTrue);
    });

    test('ACTIVE -> TYPING and ACTIVE -> CLOSING', () {
      final s = at(UniversalSearchPhase.active);
      expect(s.canGoTo(UniversalSearchPhase.typing), isTrue);
      expect(s.canGoTo(UniversalSearchPhase.closing), isTrue);
    });

    test('TYPING -> ACTIVE, TYPING -> SEARCHING, TYPING -> CLOSING', () {
      final s = at(UniversalSearchPhase.typing);
      expect(s.canGoTo(UniversalSearchPhase.active), isTrue);
      expect(s.canGoTo(UniversalSearchPhase.searching), isTrue);
      expect(s.canGoTo(UniversalSearchPhase.closing), isTrue);
    });

    test('SEARCHING -> RESULTS, AI_RESULT, ACTIVE', () {
      final s = at(UniversalSearchPhase.searching);
      expect(s.canGoTo(UniversalSearchPhase.results), isTrue);
      expect(s.canGoTo(UniversalSearchPhase.aiResult), isTrue);
      expect(s.canGoTo(UniversalSearchPhase.active), isTrue);
    });

    test('RESULTS -> TYPING, SEARCHING, CLOSING', () {
      final s = at(UniversalSearchPhase.results);
      expect(s.canGoTo(UniversalSearchPhase.typing), isTrue);
      expect(s.canGoTo(UniversalSearchPhase.searching), isTrue);
      expect(s.canGoTo(UniversalSearchPhase.closing), isTrue);
    });

    test('AI_RESULT -> SEARCHING, TYPING, CLOSING', () {
      final s = at(UniversalSearchPhase.aiResult);
      expect(s.canGoTo(UniversalSearchPhase.searching), isTrue);
      // The edit-query chip leaves results for the field — mirrored with
      // RESULTS -> TYPING (US-1 FINAL FIX).
      expect(s.canGoTo(UniversalSearchPhase.typing), isTrue);
      expect(s.canGoTo(UniversalSearchPhase.closing), isTrue);
    });

    test('CLOSING -> CLOSED', () {
      expect(at(UniversalSearchPhase.closing).canGoTo(UniversalSearchPhase.closed), isTrue);
    });
  });

  group('forbidden transitions', () {
    test('CLOSED cannot jump anywhere except OPENING', () {
      final s = at(UniversalSearchPhase.closed);
      for (final phase in UniversalSearchPhase.values) {
        final expected = phase == UniversalSearchPhase.opening;
        expect(s.canGoTo(phase), expected,
            reason: 'CLOSED -> ${phase.name}');
      }
    });

    test('OPENING -> ACTIVE and OPENING -> TYPING (preserved query reopen)', () {
      final s = at(UniversalSearchPhase.opening);
      expect(s.canGoTo(UniversalSearchPhase.active), isTrue);
      // Reopening with a preserved query enters TYPING directly (STEP 8).
      expect(s.canGoTo(UniversalSearchPhase.typing), isTrue);
      expect(s.canGoTo(UniversalSearchPhase.searching), isFalse);
      expect(s.canGoTo(UniversalSearchPhase.closed), isFalse);
    });

    test('ACTIVE cannot jump to RESULTS directly', () {
      expect(
        at(UniversalSearchPhase.active).canGoTo(UniversalSearchPhase.results),
        isFalse,
      );
    });

    test('AI_RESULT cannot jump to ACTIVE directly', () {
      expect(
        at(UniversalSearchPhase.aiResult).canGoTo(UniversalSearchPhase.active),
        isFalse,
      );
    });

    test('SEARCHING cannot close mid-flight', () {
      expect(
        at(UniversalSearchPhase.searching).canGoTo(UniversalSearchPhase.closing),
        isFalse,
      );
    });

    test('CLOSING cannot reopen (must go through CLOSED)', () {
      final s = at(UniversalSearchPhase.closing);
      expect(s.canGoTo(UniversalSearchPhase.opening), isFalse);
      expect(s.canGoTo(UniversalSearchPhase.active), isFalse);
    });

    test('no self-transitions counted as moves', () {
      for (final phase in UniversalSearchPhase.values) {
        expect(at(phase).canGoTo(phase), isFalse,
            reason: '${phase.name} -> itself');
      }
    });
  });

  group('query preservation state', () {
    test('query survives copyWith untouched', () {
      final s = UniversalSearchState(
        phase: UniversalSearchPhase.typing,
        query: 'hotels in dubai',
      );
      final next = s.copyWith(phase: UniversalSearchPhase.closing);
      expect(next.query, 'hotels in dubai');
    });

    test('reopen with preserved query targets TYPING through surfaceReady contract', () {
      // The contract: a preserved non-empty query reopens in TYPING.
      // Mirrored here at the state level.
      const query = 'hotels in dubai';
      const state = UniversalSearchState(
        phase: UniversalSearchPhase.opening,
        query: query,
      );
      final target = query.trim().isNotEmpty
          ? UniversalSearchPhase.typing
          : UniversalSearchPhase.active;
      expect(state.canGoTo(target), isTrue);
    });
  });
}
