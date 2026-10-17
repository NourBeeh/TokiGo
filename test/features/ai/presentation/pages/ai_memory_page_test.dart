import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/memory/memory_model.dart';
import 'package:tokigo/core/memory/memory_repository.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';
import 'package:tokigo/core/storage/secure_token_storage_provider.dart';
import 'package:tokigo/features/ai/application/memory_controls_providers.dart';
import 'package:tokigo/features/ai/presentation/pages/ai_memory_page.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// 2C-C2 — "What I Know About You" page widget tests.
///
/// Covers: guest sign-in prompt (no memory surface), the memory list with
/// human-readable values (never raw fields), empty state, edit flow
/// (validation → save → refresh), delete flow, clear-all flow (never the
/// wipe-everything endpoint), and RTL layout sanity.
class _FakeTokenStorage implements SecureTokenStorage {
  _FakeTokenStorage(this.token);

  final String? token;

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> saveAccessToken(String value) async {}

  @override
  Future<void> saveRefreshToken(String value) async {}

  @override
  Future<void> deleteAccessToken() async {}

  @override
  Future<void> deleteRefreshToken() async {}

  @override
  Future<void> clearAll() async {}
}

class _ScriptedRepository implements MemoryRepository {
  _ScriptedRepository(this.records);

  List<MemoryRecord> records;
  final List<String> calls = <String>[];

  @override
  Future<ApiResult<List<MemoryRecord>>> getMyMemories({
    String? type,
    String? source,
    bool includeExpired = false,
  }) async {
    calls.add('list');
    return ApiResult.success(List.of(records));
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
    final index = records.indexWhere((m) => m.id == id);
    final old = records[index];
    final updated = MemoryRecord(
      id: id,
      type: old.type,
      key: old.key,
      value: value ?? old.value,
      source: old.source,
      confidence: old.confidence,
      expiresAt: old.expiresAt,
      updatedAt: old.updatedAt,
    );
    records[index] = updated;
    return ApiResult.success(updated);
  }

  @override
  Future<ApiResult<void>> deleteMemory(String id) async {
    calls.add('delete:$id');
    records.removeWhere((m) => m.id == id);
    return const ApiResult.success(null);
  }

  @override
  Future<ApiResult<void>> clearMyMemories() async {
    calls.add('clearAllEndpoint');
    return const ApiResult.success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

MemoryRecord _record(
  String id,
  String key,
  Map<String, dynamic> value,
) {
  return MemoryRecord(
    id: id,
    type: 'conversation',
    key: key,
    value: value,
    source: 'ai_conversation',
    confidence: 0.9,
  );
}

Widget host({Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const AiMemoryPage(),
  );
}

void main() {
  late _ScriptedRepository repository;
  late _FakeTokenStorage tokenStorage;

  List<Override> overrides() => <Override>[
        memoryControlsRepositoryProvider.overrideWithValue(repository),
        secureTokenStorageProvider.overrideWithValue(tokenStorage),
      ];

  final sample = <MemoryRecord>[
    _record('1', 'preferred_destination:paris',
        const {'destination': 'Paris'}),
    _record('2', 'preferred_budget', const {'min': 100, 'max': 500}),
    _record('3', 'preferred_travel_style', const {'styles': ['Luxury']}),
  ];

  testWidgets('GUEST: shows the sign-in prompt, no memory surface',
      (tester) async {
    repository = _ScriptedRepository(sample);
    tokenStorage = _FakeTokenStorage(null);

    await tester.pumpWidget(ProviderScope(
      overrides: overrides(),
      child: host(),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Sign in to see and manage what the AI remembers about you.'),
      findsOneWidget,
    );
    // No memory values leak to a guest.
    expect(find.text('Paris'), findsNothing);
  });

  testWidgets('SIGNED-IN: lists human-readable memories, no raw fields',
      (tester) async {
    repository = _ScriptedRepository(sample);
    tokenStorage = _FakeTokenStorage('jwt');

    await tester.pumpWidget(ProviderScope(
      overrides: overrides(),
      child: host(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('What I Know About You'), findsOneWidget);
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('100 – 500'), findsOneWidget);
    expect(find.text('Luxury'), findsOneWidget);
    // Raw fields never render: no ids, no source, no confidence, no keys.
    expect(find.text('ai_conversation'), findsNothing);
    expect(find.textContaining('0.9'), findsNothing);
    expect(find.text('preferred_destination:paris'), findsNothing);
  });

  testWidgets('EMPTY: shows the empty state with a retry', (tester) async {
    repository = _ScriptedRepository(<MemoryRecord>[]);
    tokenStorage = _FakeTokenStorage('jwt');

    await tester.pumpWidget(ProviderScope(
      overrides: overrides(),
      child: host(),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Nothing yet. Facts you share with the AI assistant will appear here.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    // No clear-all bar on an empty list.
    expect(find.text('Clear all'), findsNothing);
  });

  testWidgets('DELETE: removes the row and shows the confirmation',
      (tester) async {
    repository = _ScriptedRepository(List.of(sample));
    tokenStorage = _FakeTokenStorage('jwt');

    await tester.pumpWidget(ProviderScope(
      overrides: overrides(),
      child: host(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();

    expect(repository.calls, contains('delete:1'));
    expect(find.text('Paris'), findsNothing);
    expect(find.text('Removed.'), findsOneWidget);
    expect(find.text('100 – 500'), findsOneWidget); // others intact
  });

  testWidgets('CLEAR ALL: confirms, deletes the listed rows one-by-one, '
      'never calls the wipe-everything endpoint', (tester) async {
    repository = _ScriptedRepository(List.of(sample));
    tokenStorage = _FakeTokenStorage('jwt');

    await tester.pumpWidget(ProviderScope(
      overrides: overrides(),
      child: host(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    // Confirmation dialog — the last 'Clear all' is the dialog's action.
    await tester.tap(find.text('Clear all').last);
    await tester.pumpAndSettle();

    expect(repository.calls,
        containsAll(<String>['delete:1', 'delete:2', 'delete:3']));
    // The DELETE /memory/me verb must NEVER fire from this page — it would
    // wipe behavioral/derived data, which the phase forbids.
    expect(repository.calls.contains('clearAllEndpoint'), isFalse);
    expect(find.text('All facts removed.'), findsOneWidget);
    expect(find.text('Paris'), findsNothing);
  });

  testWidgets('EDIT: opens the sheet, validates, saves, and refreshes the '
      'card', (tester) async {
    repository = _ScriptedRepository(List.of(sample));
    tokenStorage = _FakeTokenStorage('jwt');

    await tester.pumpWidget(ProviderScope(
      overrides: overrides(),
      child: host(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();

    // Destination editor sheet.
    expect(find.byType(TextField), findsOneWidget);

    // Invalid: whitespace-only value fails client-side, no network call.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Destination cannot be empty.'), findsOneWidget);
    expect(
      repository.calls.where((c) => c.startsWith('update:')),
      isEmpty,
    );

    // Valid value saves and swaps the card in place.
    await tester.enterText(find.byType(TextField), 'Rome');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('update:1'));
    expect(find.text('Rome'), findsOneWidget);
    expect(find.text('Paris'), findsNothing);
  });

  testWidgets('RTL: the Arabic page renders mirrored without exceptions',
      (tester) async {
    repository = _ScriptedRepository(List.of(sample));
    tokenStorage = _FakeTokenStorage('jwt');

    await tester.pumpWidget(ProviderScope(
      overrides: overrides(),
      child: host(locale: const Locale('ar')),
    ));
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(AiMemoryPage))),
      TextDirection.rtl,
    );
    expect(find.text('اللي أعرفه عنك'), findsOneWidget);
    // The stored VALUE stays as stored (never re-translated) — only chrome
    // localizes.
    expect(find.text('Paris'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
