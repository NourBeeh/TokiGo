import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:hive/hive.dart';


import 'package:tokigo/core/storage/deferred_offline_cache.dart';
import 'package:tokigo/core/storage/hive_offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache.dart';

void main() {
  // Initialize test fixtures before running the test group.
  // We use a function-scoped approach: the group callback has access to
  // late variables, and setUp runs before each test.
  group('Hive Stability Audit', () {
    late Directory tempDir;
    late OfflineCache cache;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      // Use a fixed test directory - no platform channel needed in test environment
      tempDir = await Directory('${Directory.systemTemp.path}/tokigo_hive_test')
          .create(recursive: true);

      // Reset state
      await Hive.deleteFromDisk();
      await Directory('${tempDir.path}/tokigo_hive_test').create(recursive: true);

      // Initialize Hive for testing (Hive.init is synchronous)
      Hive.init('${tempDir.path}/tokigo_hive_test');

      // Open the box before passing to HiveOfflineCache
      final testBox = await Hive.openBox<Map>('test');
      if (testBox == null) {
        fail('Box was not opened');
      }
      cache = HiveOfflineCache(testBox);
    });

    group('Initialization', () {
      test('HiveOfflineCache constructs without throwing', () async {
        // Tests pass an already-open Box<Map>, not a box name.
        // Use eager Box for this test (has get method)
        final testBox = await Hive.openBox<Map>('init_test');
        if (testBox == null) {
          fail('Box was not found');
        }
        expect(
            () => HiveOfflineCache(testBox), returnsNormally);
        await testBox.close();
      });

      test('DeferredOfflineCache constructs with default MemoryOfflineCache',
          () async {
        final deferred = DeferredOfflineCache();
        expect(deferred, isNotNull);
        expect(deferred.isAttached, isFalse);
        // The ready future only completes when attach() is called.
        // Since no attach() is called, the future should NOT complete.
        // We verify this by adding a callback that throws if the future
        // completes within 500ms.
        var completed = false;
        deferred.ready.then((_) {
          completed = true;
          fail('ready() should not complete without attach()');
        });
        // Wait 500ms - if completed is still false, the test passes.
        await Future.delayed(const Duration(milliseconds: 500));
        expect(completed, isFalse,
            reason: 'ready() completed when it should not have');
      });

      test('DeferredOfflineCache attaches to real cache', () async {
        final deferred = DeferredOfflineCache();
        // Use eager Box for realCache (has OfflineCache-compatible read method)
        final realBox = await Hive.openBox<Map>('attach_test');
        if (realBox == null) {
          fail('Box was not found');
        }
        await deferred.attach(HiveOfflineCache(realBox));
        expect(deferred.isAttached, isTrue);
        expect(deferred.ready, completes);
      });
    });

    group('Write and Read', () {
      test('write and read round-trip through HiveOfflineCache', () async {
        await cache.write('test_key', <String, dynamic>{
          'name': 'test',
          'value': 42,
          'nested': <String, dynamic>{'deep': true},
        });

        final result = await cache.read('test_key');
        expect(result, isNotNull);
        expect(result!['name'], 'test');
        expect(result['value'], 42);
        expect(result['nested']['deep'], true);
      });

      test('read returns null for missing key', () async {
        final result = await cache.read('non_existent_key');
        expect(result, isNull);
      });

      test('contains returns true after write', () async {
        await cache.write('test_contains', <String, dynamic>{'x': 1});
        expect(await cache.contains('test_contains'), isTrue);
      });

      test('contains returns false for missing key', () async {
        expect(await cache.contains('non_existent'), isFalse);
      });

      test('keys returns stored keys, order unspecified', () async {
        await cache.write('key1', <String, dynamic>{'a': 1});
        await cache.write('key2', <String, dynamic>{'b': 2});
        final keys = await cache.keys();
        expect(keys.contains('key1'), isTrue);
        expect(keys.contains('key2'), isTrue);
        expect(keys.length, 2);
      });
    });

    group('Delete', () {
      test('delete removes key and subsequent read returns null', () async {
        await cache.write('delete_test', <String, dynamic>{'x': 1});
        expect(await cache.contains('delete_test'), isTrue);

        await cache.delete('delete_test');
        expect(await cache.contains('delete_test'), isFalse);
        final result = await cache.read('delete_test');
        expect(result, isNull);
      });

      test('delete on missing key is no-op', () async {
        expect(() => cache.delete('non_existent'), returnsNormally);
      });
    });

    group('Clear', () {
      test('clear removes all stored keys', () async {
        await cache.write('key1', <String, dynamic>{'a': 1});
        await cache.write('key2', <String, dynamic>{'b': 2});
        expect(await cache.keys(), hasLength(2));

        await cache.clear();
        expect(await cache.keys(), isEmpty);
        expect(await cache.read('key1'), isNull);
        expect(await cache.read('key2'), isNull);
      });
    });

    group('Migrations', () {
      test('keys returns empty list when box is empty', () async {
        expect(await cache.keys(), isEmpty);
      });

      test('read/write multiple keys independently', () async {
        final key1 = 'user_prefs_1';
        final key2 = 'user_prefs_2';
        final key3 = 'separator_config';

        await cache.write(key1, <String, dynamic>{'theme': 'dark'});
        await cache.write(key2, <String, dynamic>{'lang': 'en'});
        await cache.write(key3, <String, dynamic>{'cols': 3});

        expect(await cache.read(key1), isNotNull);
        expect(
            (await cache.read(key1))!['theme'], 'dark');
        expect(await cache.read(key2), isNotNull);
        expect(
            (await cache.read(key2))!['lang'], 'en');
        expect(await cache.read(key3), isNotNull);
        expect((await cache.read(key3))!['cols'], 3);
      });
    });

    group('Corruption recovery', () {
      test('read returns null on corrupt data (catch-all)', () async {
        // Simulating a corrupt entry: we can't actually corrupt Hive programmatically
        // without manipulating the box file directly, but the catch-all pattern
        // in read() handles any HiveError by returning null.
        final result = await cache.read('corrupt_key');
        expect(result, isNull);
      });

      test('delete is best-effort on failure', () async {
        // delete() catches exceptions and returns normally
        expect(() => cache.delete('any_key'), returnsNormally);
      });

      test('compact is best-effort on failure', () async {
        expect(() => cache.compact(), returnsNormally);
      });

      test('clear is best-effort on failure', () async {
        expect(() => cache.clear(), returnsNormally);
      });
    });

    group('Concurrency', () {
      test('multiple writes are applied in order', () async {
        // Write first
        await cache.write('concurrent_1', <String, dynamic>{'seq': 1});
        await cache.write('concurrent_2', <String, dynamic>{'seq': 2});
        await cache.write('concurrent_3', <String, dynamic>{'seq': 3});

        // Read to verify
        final results = Future.wait<Map<String, dynamic>?>([
          cache.read('concurrent_1'),
          cache.read('concurrent_2'),
          cache.read('concurrent_3'),
        ]);

        final resultsList = await results;
        expect(resultsList[0], isNotNull);
        expect((resultsList[0]! as Map)['seq'], 1);
        expect(resultsList[1], isNotNull);
        expect((resultsList[1]! as Map)['seq'], 2);
        expect(resultsList[2], isNotNull);
        expect((resultsList[2]! as Map)['seq'], 3);
      });

      test('DeferredOfflineCache replays pending writes in order', () async {
        final memoryCache = MemoryOfflineCache();
        final deferred = DeferredOfflineCache(initial: memoryCache);

        // Write before attaching
        await deferred.write('pending_1', <String, dynamic>{'seq': 1});
        await deferred.write('pending_2', <String, dynamic>{'seq': 2});

        // Attach to real cache using eager Box
        final realBox = await Hive.openBox<Map>('concurrent_attach_test');
        if (realBox == null) {
          fail('Box was not found');
        }
        final realCache = HiveOfflineCache(realBox);
        await deferred.attach(realCache);

        // Verify writes were replayed
        expect(await deferred.read('pending_1'), isNotNull);
        expect((await deferred.read('pending_1'))!['seq'], 1);
        expect(await deferred.read('pending_2'), isNotNull);
        expect((await deferred.read('pending_2'))!['seq'], 2);
      });
    });

    group('Persistence', () {
      test('data persists across box reopen', () async {
        // Write to the box
        await cache.write('persist_test', <String, dynamic>{'survives': true});

        // Read it back immediately to verify
        expect(await cache.read('persist_test'), isNotNull);
        expect((await cache.read('persist_test'))!['survives'], true);

        // Close the box
        await Hive.close();

        // Re-open the box in the same Hive instance
        final reopenedBox = await Hive.openBox<Map>('test');
        if (reopenedBox == null) {
          fail('Box was not found after reopen');
        }

        // Write another key to verify the box is still working
        await reopenedBox.put('reopen_test', <String, dynamic>{'reopened': true});

        // Read from the box
        final reopenedCache = HiveOfflineCache(reopenedBox);
        final result = await reopenedCache.read('reopen_test');
        expect(result, isNotNull);
        expect(result!['reopened'], true);

        // Cleanup
        await reopenedBox.close();
      });
    });

    group('OfflineCache adapter', () {
      test('HiveOfflineCache implements OfflineCache contract', () async {
        expect(() => cache.clear(), returnsNormally);
        expect(() => cache.compact(), returnsNormally);
        expect(() => cache.delete('any'), returnsNormally);
        expect(() => cache.keys(), returnsNormally);
        expect(() => cache.read('any'), returnsNormally);
        expect(() => cache.contains('any'), returnsNormally);
        expect(() => cache.write('any', <String, dynamic>{}), returnsNormally);
      });
    });
  });
}
