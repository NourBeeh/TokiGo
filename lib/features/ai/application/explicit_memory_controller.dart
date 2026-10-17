import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/memory/memory_model.dart';
import 'package:tokigo/core/memory/memory_repository.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/features/ai/domain/explicit_memory_view.dart';

/// 2C-C2 — Controller for the "What I Know About You" memory controls.
///
/// Lists the caller's EXPLICIT conversation memories (strict 2C vocabulary
/// only) through the EXISTING Phase 2A [MemoryRepository] — no new backend,
/// no new state machinery. Edit/Delete/Clear are the 2A verbs, nothing else.
///
/// Scope guarantees (the phase's do-NOT list, as code):
/// - rows outside the 3-kind vocabulary are INVISIBLE here, never mutated;
/// - "Clear all" deletes ONLY the listed explicit conversation memories one
///   by one — `clearMyMemories()` (DELETE /memory/me) would also wipe
///   behavioral/derived data, which the spec forbids ("حذف memory لا يعني
///   حذف profile/behavioral data"), so it is deliberately NOT used;
/// - no Home Ranking, no DerivedPreferenceProfile, no memory→ranking path.
class ExplicitMemoryController
    extends StateNotifier<ExplicitMemoryState> {
  ExplicitMemoryController(this._repository, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(const ExplicitMemoryState());

  final MemoryRepository _repository;

  /// Injectable clock for deterministic expiry handling in tests.
  final DateTime Function() _now;

  /// Server-side hidden-but-present rows (includeExpired=true) still show
  /// their values; we filter client-side too so the contract holds even if
  /// a stale backend returns expired rows on the default listing.
  static bool isExpired(MemoryRecord record, {required DateTime now}) {
    final expiry = record.expiresAt;
    if (expiry == null || expiry.isEmpty) return false;
    final parsed = DateTime.tryParse(expiry);
    if (parsed == null) return false;
    return parsed.isBefore(now);
  }

  /// Loads the caller's explicit conversation memories.
  Future<void> load() async {
    state = state.copyWith(status: ExplicitMemoryStatus.loading);
    final result = await _repository.getMyMemories(
      type: 'conversation',
      includeExpired: false,
    );
    result.when(
      success: (records) {
        final views = <ExplicitMemoryView>[];
        for (final record in records) {
          if (isExpired(record, now: _now())) continue;
          final view = ExplicitMemoryView.fromRecord(record);
          if (view != null) views.add(view);
        }
        state = ExplicitMemoryState(
          status: ExplicitMemoryStatus.ready,
          memories: views,
        );
      },
      failure: (error) {
        state = state.copyWith(
          status: ExplicitMemoryStatus.error,
          errorMessage: _messageFor(error),
          // Keep the previous list visible on a refresh failure — the page
          // shows the error inline without wiping what the user had.
          memories: state.memories,
        );
      },
    );
  }

  /// Rewrites one explicit memory's value (2A upsert on type+key).
  ///
  /// [value] must already be validated ([ExplicitMemoryInput.validate]).
  Future<bool> updateValue(
      ExplicitMemoryView view, Map<String, dynamic> value) async {
    final result = await _repository.updateMemory(
      view.record.id,
      value: value,
    );
    final updated = result.valueOrNull;
    if (updated == null) {
      _surfaceError(result.errorOrNull);
      return false;
    }
    // Optimistic local swap: replace the row in place, keep order.
    final next = ExplicitMemoryView.fromRecord(updated);
    if (next != null) {
      state = state.copyWith(
        memories: [
          for (final m in state.memories)
            m.record.id == updated.id ? next : m,
        ],
      );
    }
    return true;
  }

  /// Deletes one explicit memory row.
  Future<bool> delete(ExplicitMemoryView view) async {
    final result = await _repository.deleteMemory(view.record.id);
    if (result.isFailure) {
      _surfaceError(result.errorOrNull);
      return false;
    }
    state = state.copyWith(
      memories: [
        for (final m in state.memories) if (m.record.id != view.record.id) m,
      ],
    );
    return true;
  }

  /// Deletes EVERY listed explicit memory — and nothing else.
  ///
  /// Sequential deletes of the currently listed rows; the caller's other
  /// memory categories (behavior/derived) are untouched. A failed row aborts
  /// the sweep with an error surfaced (already-deleted rows are treated as
  /// success — idempotent).
  Future<bool> clearAll() async {
    final ids = [for (final m in state.memories) m.record.id];
    for (final id in ids) {
      final result = await _repository.deleteMemory(id);
      if (result.isFailure) {
        final error = result.errorOrNull;
        // 404 → already gone: continue the sweep instead of failing it.
        if (error is ApiClientError &&
            (error.message ?? '').contains('not found')) {
          continue;
        }
        _surfaceError(error);
        return false;
      }
    }
    state = state.copyWith(memories: []);
    return true;
  }

  void dismissError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }

  void _surfaceError(Object? error) {
    state = state.copyWith(
      errorMessage: error is ApiError
          ? _messageFor(error)
          : 'Something went wrong. Please try again.',
    );
  }

  static String _messageFor(Object error) {
    if (error is ApiError) {
      return switch (error) {
        ApiTimeoutError() =>
          'The request took too long. Please try again.',
        ApiNetworkError() =>
          'No connection. Check your internet and try again.',
        ApiUnauthorizedError() =>
          'Your session has expired. Please sign in and try again.',
        ApiParseError() =>
          'The response was unreadable. Please try again.',
        ApiServerError() =>
          'The service is temporarily unavailable. Please try again shortly.',
        ApiClientError() => error.message?.isNotEmpty == true
            ? error.message!
            : 'That request could not be handled. Please try again.',
        ApiRequestCancelledError() => 'Request cancelled.',
        ApiUnknownError() => _genericMessage,
      };
    }
    return _genericMessage;
  }

  static const String _genericMessage =
      'Something went wrong. Please try again.';
}

/// Lifecycle of the memory-controls surface.
enum ExplicitMemoryStatus { loading, ready, error }

/// Immutable state for the "What I Know About You" page.
class ExplicitMemoryState {
  const ExplicitMemoryState({
    this.status = ExplicitMemoryStatus.loading,
    this.memories = const <ExplicitMemoryView>[],
    this.errorMessage,
  });

  final ExplicitMemoryStatus status;

  /// The caller's explicit conversation memories, vocabulary-filtered.
  final List<ExplicitMemoryView> memories;

  /// Inline error message for the last failed action (load/edit/delete).
  final String? errorMessage;

  bool get isEmpty => memories.isEmpty;

  ExplicitMemoryState copyWith({
    ExplicitMemoryStatus? status,
    List<ExplicitMemoryView>? memories,
    String? errorMessage,
  }) {
    return ExplicitMemoryState(
      status: status ?? this.status,
      memories: memories ?? this.memories,
      errorMessage: errorMessage,
    );
  }
}
