import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/ai/ai_assistant_service.dart';
import 'package:tokigo/core/network/user_facing_message.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/features/ai/application/ai_providers.dart';
import 'package:tokigo/features/ai/application/ai_state.dart';
import 'package:tokigo/features/ai/domain/ai_home_mapper.dart';
import 'package:tokigo/features/ai/domain/ai_query_context.dart';
import 'package:tokigo/features/home/presentation/widgets/home_section.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_serializers.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';

class AiSheetController extends StateNotifier<AiState> {
  AiSheetController({
    required AiAssistantService service,
    required this.mapper,
    required OfflineCache cache,
  })  : _service = service,
        _cache = cache,
        super(const AiState());

  final AiAssistantService _service;
  final AiHomeMapper mapper;
  final OfflineCache _cache;

  int _requestVersion = 0;
  bool _disposed = false;

  Future<void> load(String prompt, {AiQueryContext? context}) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final cacheKey = aiQueryCacheKey(prompt: trimmed, context: context);

    // Try to load from cache first. Best-effort: a corrupt or unreadable
    // entry must never block the live request below.
    try {
      final cached = await _cache.read(cacheKey);
      if (cached != null) {
        final cachedResponse = aiResponseFromMap(cached);
        if (cachedResponse != null) {
          final sections = mapper.toHomeSections(cachedResponse);
          final text = cachedResponse.text;

          if (sections.isNotEmpty ||
              (text != null && text.trim().isNotEmpty)) {
            state = state.copyWith(
              status: AiStatus.success,
              currentPrompt: trimmed,
              responseText: text,
              sections: sections,
              errorMessage: null,
              fromCache: true,
            );
          }
        }
      }
    } catch (_) {
      // Ignore cache read failures — proceed with a live request.
    }

    final requestVersion = ++_requestVersion;
    state = state.copyWith(
      status: AiStatus.loading,
      currentPrompt: trimmed,
      errorMessage: null,
    );

    try {
      final token = RequestToken();
      final response = await _service
          .query(trimmed, token: token, context: context)
          .timeout(const Duration(seconds: 90));
      if (_disposed || requestVersion != _requestVersion) {
        return;
      }

      final sections = mapper.toHomeSections(response);

      // Write to cache (best-effort)
      try {
        await _cache.write(cacheKey, aiResponseToMap(response));
      } catch (_) {
        // Ignore cache write failures
      }

      state = state.copyWith(
        status: sections.isEmpty &&
                (response.text == null || response.text!.trim().isEmpty)
            ? AiStatus.empty
            : AiStatus.success,
        currentPrompt: trimmed,
        responseText: response.text,
        sections: sections,
        errorMessage: null,
        fromCache: false,
      );
    } catch (error) {
      if (_disposed || requestVersion != _requestVersion) {
        return;
      }
      // On network failure, show cached results if available
      if (state.fromCache && state.sections.isNotEmpty) {
        state = state.copyWith(
          status: AiStatus.success,
          currentPrompt: trimmed,
          errorMessage: userFacingMessage(error, subject: 'AI assistant'),
        );
      } else {
        state = state.copyWith(
          status: AiStatus.error,
          currentPrompt: trimmed,
          errorMessage: userFacingMessage(error, subject: 'AI assistant'),
          fromCache: false,
        );
      }
    }
  }

  void cancel() {
    _requestVersion++;
    state = const AiState();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}

final aiSheetControllerProvider =
    StateNotifierProvider.autoDispose.family<AiSheetController, AiState, ({String prompt, AiQueryContext? context})>(
  (ref, args) {
    final controller = AiSheetController(
      service: ref.watch(aiAssistantServiceProvider),
      mapper: ref.watch(aiHomeMapperProvider),
      cache: ref.watch(offlineCacheProvider),
    );
    Future.microtask(() => controller.load(args.prompt, context: args.context));
    return controller;
  },
);

class AiBottomSheetContent extends ConsumerWidget {
  const AiBottomSheetContent({super.key, required this.prompt, this.aiContext});

  final String prompt;
  final AiQueryContext? aiContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiSheetControllerProvider((prompt: prompt, context: aiContext)));
    final controller = ref.read(aiSheetControllerProvider((prompt: prompt, context: aiContext)).notifier);

    final children = switch (state.status) {
      AiStatus.loading => const [Center(child: CircularProgressIndicator())],
      AiStatus.error => [Center(child: Text(state.errorMessage ?? 'Something went wrong. Please try again.'))],
      AiStatus.empty => const [Center(child: Text('No suggestions right now. Try a different prompt.'))],
      AiStatus.success => [
          ...state.sections.map(
            (section) => HomeSectionWidget(section: section),
          ),
        ],
      AiStatus.idle => const [SizedBox.shrink()],
    };

    return Material(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            if (state.status == AiStatus.error)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => controller.load(state.currentPrompt),
                  child: const Text('Try again'),
                ),
              ),
            Expanded(
              child: children.length == 1 && children.first is Center
                  ? children.first
                  : ListView(
                      children: children,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a draggable AI bottom sheet over the current surface.
///
/// The sheet is deliberately size-bounded (max 75% of screen height) so it
/// can never read as a full-screen takeover: the top header area always
/// stays visible, and an explicit close button sits in the sheet header.
Future<void> showAiBottomSheet(BuildContext context, String prompt, {AiQueryContext? aiContext}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.25,
      maxChildSize: 0.75,
      builder: (sheetContext, scrollController) {
        return Consumer(
          builder: (consumerContext, ref, _) {
            final state = ref.watch(aiSheetControllerProvider((prompt: prompt, context: aiContext)));
            final controller = ref.read(aiSheetControllerProvider((prompt: prompt, context: aiContext)).notifier);
            final sections = state.sections;
            final Widget body = switch (state.status) {
              AiStatus.loading => const Center(child: CircularProgressIndicator()),
              AiStatus.error => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Text(
                        state.errorMessage ??
                            'Something went wrong. Please try again.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () => controller.load(state.currentPrompt),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              AiStatus.empty => const Center(
                  child: Text('No suggestions right now. Try a different prompt.'),
                ),
              // Friendly idle state shown when the sheet is opened from the
              // persistent bubble with no prompt yet.
              AiStatus.idle => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_outlined,
                          size: 40, color: AppColors.ai.withValues(alpha: 0.5)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Ask about flights, hotels & more…',
                        style: Theme.of(consumerContext).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(consumerContext).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              AiStatus.success => ListView.builder(
                  controller: scrollController,
                  itemCount: sections.length,
                  itemBuilder: (context, index) =>
                      HomeSectionWidget(section: sections[index]),
                ),
            };
            return Material(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: AppSpacing.sm),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(consumerContext).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header with explicit close affordance
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                  Expanded(child: body),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}