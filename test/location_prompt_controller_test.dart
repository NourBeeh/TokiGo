import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/geo/location_prompt_controller.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('LocationPromptController', () {
    test('shows at most twice, then stays silent', () async {
      final container = ProviderContainer(
        overrides: <Override>[
          offlineCacheProvider.overrideWithValue(MemoryOfflineCache()),
        ],
      );
      addTearDown(container.dispose);

      container.read(locationPromptControllerProvider);
      await _settle();

      final controller =
          container.read(locationPromptControllerProvider.notifier);
      expect(controller.mayShow(), isTrue);

      await controller.recordImpression();
      expect(controller.mayShow(), isTrue);

      await controller.recordImpression();
      expect(controller.mayShow(), isFalse);

      await controller.recordImpression();
      expect(
        container.read(locationPromptControllerProvider).impressions,
        LocationPromptController.maxImpressions,
      );
    });

    test('a dismissal silences the prompt for 14 days', () async {
      final container = ProviderContainer(
        overrides: <Override>[
          offlineCacheProvider.overrideWithValue(MemoryOfflineCache()),
        ],
      );
      addTearDown(container.dispose);

      container.read(locationPromptControllerProvider);
      await _settle();

      final controller =
          container.read(locationPromptControllerProvider.notifier);
      final DateTime dismissedAt = DateTime.utc(2026, 1, 1);
      await controller.dismiss(now: dismissedAt);

      expect(controller.mayShow(now: dismissedAt), isFalse);
      expect(
        controller.mayShow(
          now: dismissedAt.add(const Duration(days: 13, hours: 23)),
        ),
        isFalse,
      );
      expect(
        controller.mayShow(
          now: dismissedAt.add(LocationPromptController.cooldown),
        ),
        isTrue,
      );
    });

    test('the persisted counters survive a restart', () async {
      final cache = MemoryOfflineCache();
      final first = ProviderContainer(
        overrides: <Override>[offlineCacheProvider.overrideWithValue(cache)],
      );
      first.read(locationPromptControllerProvider);
      await _settle();
      final controller =
          first.read(locationPromptControllerProvider.notifier);
      await controller.recordImpression();
      await controller.dismiss(now: DateTime.utc(2026, 2, 1));
      first.dispose();

      final second = ProviderContainer(
        overrides: <Override>[offlineCacheProvider.overrideWithValue(cache)],
      );
      addTearDown(second.dispose);
      second.read(locationPromptControllerProvider);
      await _settle();

      final state = second.read(locationPromptControllerProvider);
      expect(state.impressions, 1);
      expect(state.dismissedAt, DateTime.utc(2026, 2, 1));
      expect(
        second
            .read(locationPromptControllerProvider.notifier)
            .mayShow(now: DateTime.utc(2026, 2, 10)),
        isFalse,
      );
    });
  });
}
