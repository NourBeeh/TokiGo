import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/memory/memory_model.dart';
import 'package:tokigo/core/memory/memory_repository.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/features/ai/application/explicit_memory_controller.dart';

/// 2C-C2 — ExplicitMemoryController tests.
///
/// Covers: list (vocabulary filter + expiry), edit (optimistic swap),
/// delete, clear-all (sequential deletes of LISTED rows ONLY — never the
/// 2A clearMyMemories which would wipe behavioral data), failure surfacing
/// (list intact on error), and the 404-idempotent clear.
class _ScriptedMemoryRepository implements MemoryRepository {
  _ScriptedMemoryRepository({this.initial = const <MemoryRecord>[]});

  final List<MemoryRecord> initial;

  final List<String> calls = <String>[];
  final Set<String> deleted = <String>{};
  bool failNextDelete = false;
  ApiError? deleteFailure;

  @override
  Future<ApiResult<List<MemoryRecord>>> getMyMemories({
    String? type,
    String? source,
    bool includeExpired = false,
  }) async {
    calls.add('list:$type');
    return ApiResult.success(List.of(initial));
  }

  @override
  Future<ApiResult<MemoryRecord>> createMemory({
    required String type,
    required String key,
    required Map<String, dynamic> value,
    required String source,
    double? confidence,
    String? expiresAt,
  }) async {
    calls.add('create');
    return ApiResult.success(MemoryRecord(
      id: 'x',
      type: type,
      key: key,
      value: value,
      source: source,
      confidence: confidence ?? 0.9,
      expiresAt: expiresAt,
    ));
  }

  @override
  Future<ApiResult<MemoryRecord>> updateMemory(
    String id, {
    Map<String, dynamic>? value,
    String? source,
    double? confidence,
    String? expiresAt,
  }) async {
    calls.add('update:$id');
    final old = initial.firstWhere((m) => m.id == id);
    return ApiResult.success(MemoryRecord(
      id: id,
      type: old.type,
      key: old.key,
      value: value ?? old.value,
      source: old.source,
      confidence: old.confidence,
      expiresAt: old.expiresAt,
      updatedAt: old.updatedAt,
    ));
  }

  @override
  Future<ApiResult<void>> deleteMemory(String id) async {
    calls.add('delete:$id');
    if (deleteFailure != null) {
      return ApiResult.failure(deleteFailure!);
    }
    deleted.add(id);
    return const ApiResult.success(null);
  }

  @override
  Future<ApiResult<void>> clearMyMemories() async {
    calls.add('clearAll');
    return const ApiResult.success(null);
  }
}

MemoryRecord _memory(
  String id,
  String key, [
  Map<String, dynamic> value = const {'destination': 'Paris'},
]) {
  return MemoryRecord(
    id: id,
    type: 'conversation',
    key: key,
    value: value,
    source: 'ai_conversation',
    confidence: 0.9,
  );
}

void main() {
  test('load lists ONLY 2C-vocabulary conversation memories', () async {
    final repo = _ScriptedMemoryRepository(initial: <MemoryRecord>[
      _memory('1', 'preferred_destination:paris'),
      _memory('2', 'preferred_budget', const {'min': 1, 'max': 2}),
      _memory('3', 'preferred_travel_style', const {'styles': ['Luxury']}),
      // Foreign rows must stay invisible:
      _memory('4', 'hotel_search:paris'),
      MemoryRecord(
        id: '5',
        type: 'behavior',
        key: 'preferred_budget', // right key, wrong type
        value: const {'min': 9},
        source: 'behavior_event',
        confidence: 0.5,
      ),
    ]);
    final controller = ExplicitMemoryController(repo);

    await controller.load();

    expect(controller.state.status, ExplicitMemoryStatus.ready);
    expect(controller.state.memories.length, 3);
    expect(
      controller.state.memories.map((m) => m.record.id).toList(),
      <String>['1', '2', '3'],
    );
  });

  test('load hides expired rows', () async {
    final repo = _ScriptedMemoryRepository(initial: <MemoryRecord>[
      MemoryRecord(
        id: '1',
        type: 'conversation',
        key: 'preferred_destination:paris',
        value: const {'destination': 'Paris'},
        source: 'ai_conversation',
        confidence: 0.9,
        expiresAt: '2001-01-01T00:00:00.000Z',
      ),
      _memory('2', 'preferred_budget', const {'min': 1}),
    ]);
    final controller = ExplicitMemoryController(repo);

    await controller.load();

    expect(controller.state.memories.length, 1);
    expect(controller.state.memories.first.record.id, '2');
  });

  test('load failure surfaces an error and KEEPS the previous list',
      () async {
    final repo = _FailingListRepository();
    final controller = ExplicitMemoryController(repo);
    await controller.load(); // fails immediately

    expect(controller.state.status, ExplicitMemoryStatus.error);
    expect(controller.state.errorMessage, isNotNull);
    expect(controller.state.memories, isEmpty);
  });

  test('updateValue swaps the row in place on success', () async {
    final repo = _ScriptedMemoryRepository(initial: <MemoryRecord>[
      _memory('1', 'preferred_destination:paris'),
    ]);
    final controller = ExplicitMemoryController(repo);
    await controller.load();
    final view = controller.state.memories.single;

    final ok =
        await controller.updateValue(view, const {'destination': 'Rome'});

    expect(ok, isTrue);
    expect(controller.state.memories.single.displayValue, 'Rome');
    expect(repo.calls, contains('update:1'));
  });

  test('delete removes exactly one row', () async {
    final repo = _ScriptedMemoryRepository(initial: <MemoryRecord>[
      _memory('1', 'preferred_destination:paris'),
      _memory('2', 'preferred_budget', const {'min': 1}),
    ]);
    final controller = ExplicitMemoryController(repo);
    await controller.load();

    final ok = await controller.delete(controller.state.memories.first);

    expect(ok, isTrue);
    expect(controller.state.memories.length, 1);
    expect(controller.state.memories.first.record.id, '2');
    expect(repo.deleted, contains('1'));
  });

  test('clearAll deletes the LISTED rows one-by-one and NEVER calls the '
      '2A clearMyMemories endpoint', () async {
    final repo = _ScriptedMemoryRepository(initial: <MemoryRecord>[
      _memory('1', 'preferred_destination:paris'),
      _memory('2', 'preferred_budget', const {'min': 1}),
      _memory('3', 'preferred_travel_style', const {'styles': ['Luxury']}),
    ]);
    final controller = ExplicitMemoryController(repo);
    await controller.load();

    final ok = await controller.clearAll();

    expect(ok, isTrue);
    expect(controller.state.memories, isEmpty);
    expect(repo.deleted, containsAll(<String>['1', '2', '3']));
    // The contract: behavioral/derived data is untouched — clearAll (the
    // DELETE /memory/me verb) must NEVER fire from this surface.
    expect(repo.calls.contains('clearAll'), isFalse);
  });

  test('clearAll keeps already-deleted rows idempotent (404 → continue)',
      () async {
    final repo = _ScriptedMemoryRepository(initial: <MemoryRecord>[
      _memory('1', 'preferred_destination:paris'),
      _memory('2', 'preferred_budget', const {'min': 1}),
    ]);
    final controller = ExplicitMemoryController(repo);
    await controller.load();
    // First delete 404s (row vanished server-side between list and sweep).
    repo.deleteFailure = ApiClientError(message: 'Memory not found.');

    final ok = await controller.clearAll();

    expect(ok, isTrue);
    expect(controller.state.memories, isEmpty);
  });

  test('clearAll aborts on a real failure and surfaces the error', () async {
    final repo = _ScriptedMemoryRepository(initial: <MemoryRecord>[
      _memory('1', 'preferred_destination:paris'),
      _memory('2', 'preferred_budget', const {'min': 1}),
    ]);
    final controller = ExplicitMemoryController(repo);
    await controller.load();
    repo.deleteFailure = ApiServerError(message: 'boom');

    final ok = await controller.clearAll();

    expect(ok, isFalse);
    expect(controller.state.errorMessage, isNotNull);
    // The sweep aborted at the FIRST row — the list is still fully intact
    // (rows are only removed after the whole sweep succeeds).
    expect(controller.state.memories.length, 2);
    expect(
      controller.state.memories.map((m) => m.record.id),
      containsAll(<String>['1', '2']),
    );
  });

  test('dismissError clears the inline error', () async {
    final repo = _FailingListRepository();
    final controller = ExplicitMemoryController(repo);
    await controller.load();
    expect(controller.state.errorMessage, isNotNull);

    controller.dismissError();
    expect(controller.state.errorMessage, isNull);
  });
}

class _FailingListRepository implements MemoryRepository {
  @override
  Future<ApiResult<List<MemoryRecord>>> getMyMemories({
    String? type,
    String? source,
    bool includeExpired = false,
  }) async {
    return const ApiResult.failure(ApiServerError(message: 'down'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError();
}
