import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/features/ai/application/ai_chat_page_providers.dart';
import 'package:tokigo/features/ai/application/ai_state.dart';
import 'package:tokigo/features/ai/domain/ai_chat_message.dart';
import 'package:tokigo/features/ai/domain/ai_query_context.dart';
import 'package:tokigo/features/ai/presentation/widgets/chat_search_widgets.dart';
import 'package:tokigo/features/home/presentation/widgets/home_section.dart';
import 'package:tokigo/features/home/providers/home_providers.dart'
    show geoCountryProvider, profileRepositoryProvider;
import 'package:tokigo/features/search/domain/country_airport_suggestions.dart';
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';
import 'package:tokigo/features/universal_search/application/voice_search_providers.dart';
import 'package:tokigo/features/universal_search/application/voice_search_state.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The unified chat-first surface (TokiGo AI).
///
/// A single conversation thread that merges search and AI: the user types a
/// query, and the assistant replies with a narrative **and** real product
/// cards rendered through the existing `HomeSectionWidget` system. A complete
/// structured intent produces cards deterministically (no AI round-trip);
/// everything else rides the AI layer. Voice input feeds the same field.
///
/// Opened from the Home search box; closed via the header back button, the
/// system Back button/gesture, or Escape (web/desktop).
class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key, this.initialPrompt});

  /// The query captured by the Home search box before the chat opened.
  final String? initialPrompt;

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _chatScroll = ScrollController();
  Future<Map<String, dynamic>?>? _explicitPreferencesFuture;

  @override
  void initState() {
    super.initState();
    _textCtrl.text = widget.initialPrompt ?? '';
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    // Voice transcription lands in the SAME field (single source of truth).
    ref.read(voiceSearchControllerProvider.notifier).onTranscription =
        _onVoiceTranscription;
    // Resolve country in the background; never block opening the chat or
    // request a new location permission.
    ref.read(geoCountryProvider.future);
    _startExplicitPreferencesLoad();
    // A query handed over from the Home search box is submitted to the AI
    // immediately (not merely pre-filled): the reply lands in the thread.
    final initial = widget.initialPrompt?.trim() ?? '';
    if (initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final explicitPreferences = await _loadExplicitPreferences();
        if (!mounted) return;
        ref
            .read(aiChatControllerProvider.notifier)
            .submit(initial, context: _aiContext(explicitPreferences));
        _textCtrl.clear();
        _scheduleScrollToEnd();
      });
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _textCtrl.dispose();
    _inputFocus.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  /// Escape closes the chat (web/desktop parity with mobile Back).
  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        mounted) {
      Navigator.of(context).maybePop();
      return true;
    }
    return false;
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.mediumImpact();
    _inputFocus.unfocus();
    final explicitPreferences = await _loadExplicitPreferences();
    if (!mounted) return;
    // Same submission pathway as AiPromptInput — no duplicated logic.
    ref
        .read(aiChatControllerProvider.notifier)
        .submit(text, context: _aiContext(explicitPreferences));
    _textCtrl.clear();
    _scheduleScrollToEnd();
  }

  void _startExplicitPreferencesLoad() {
    if (ref.read(authUserProvider) == null) return;
    _explicitPreferencesFuture ??= ref
        .read(profileRepositoryProvider)
        .fetchProfile()
        .then((profile) {
          if (profile?.personalizationEnabled != true) return null;
          return profile?.explicitPreferences?.toMap();
        });
  }

  Future<Map<String, dynamic>?> _loadExplicitPreferences() {
    _startExplicitPreferencesLoad();
    return _explicitPreferencesFuture ?? Future.value(null);
  }

  AiQueryContext _aiContext(Map<String, dynamic>? explicitPreferences) {
    final country = ref.read(geoCountryProvider).asData?.value?.countryCode;
    final countryCode = country?.trim().toUpperCase();
    final suggestedOrigin = suggestedAirportCodeForCountry(countryCode);
    return AiQueryContext(
      route: 'ai-chat',
      metadata: <String, dynamic>{
        if (countryCode != null && countryCode.isNotEmpty)
          'countryCode': countryCode,
        'suggestedOrigin': ?suggestedOrigin,
        if (explicitPreferences != null && explicitPreferences.isNotEmpty)
          'explicitPreferences': explicitPreferences,
      },
    );
  }

  void _scheduleScrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScroll.hasClients) return;
      _chatScroll.jumpTo(_chatScroll.position.maxScrollExtent);
    });
  }

  // ── Voice search wiring ────────────────────────────────────────────────
  void _onVoiceTranscription(String text, bool isFinal) {
    if (!mounted) return;
    _textCtrl.text = text;
    _textCtrl.selection = TextSelection.collapsed(offset: text.length);
    if (isFinal) _inputFocus.requestFocus();
  }

  Future<void> _onMicTap() async {
    final voice = ref.read(voiceSearchControllerProvider.notifier);
    final isLive =
        ref.read(voiceSearchControllerProvider).status ==
        VoiceSearchStatus.listening;
    if (isLive) {
      await voice.stopSession();
      if (mounted) _inputFocus.requestFocus();
      return;
    }
    HapticFeedback.lightImpact();
    _inputFocus.unfocus();
    await voice.startSession();
  }

  /// A follow-up chip re-runs the last user query with a parser-recognized
  /// modifier attached.
  void _applyFollowUp(String modifier) {
    final messages = ref.read(aiChatControllerProvider).messages;
    final lastUser = messages.lastWhere(
      (m) => m.isUser,
      orElse: () => const AiChatMessage.user(''),
    );
    if (lastUser.text.isEmpty) return;
    _textCtrl.text = '${lastUser.text} $modifier';
    _textCtrl.selection = TextSelection.collapsed(
      offset: _textCtrl.text.length,
    );
    _submit();
  }

  /// Product-card tap — the shared booking hand-off. The adapted `HomeItem`
  /// carries the provider identifiers the booking flow expects.
  void _openOffer(HomeItem item) {
    HapticFeedback.lightImpact();
    final offerType = switch (item.type) {
      HomeCardType.flight => 'flight',
      HomeCardType.car => 'car',
      HomeCardType.package => 'package',
      _ => 'hotel',
    };
    ref.read(selectedOfferProvider.notifier).state = SelectedOffer(
      offerId: item.id,
      providerId: item.metadata['providerId']?.toString() ?? '',
      providerName: item.metadata['providerName']?.toString() ?? '',
      price: item.price ?? 0,
      currency: item.currency ?? 'USD',
      searchId: '',
      offerType: offerType,
      metadata: item.metadata,
      // The card's own identity, so the confirmation can name what was booked.
      title: item.title,
      subtitle: item.subtitle,
      imageUrl: item.imageUrl,
    );
    context.push('/booking/review');
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiChatControllerProvider);
    ref.listen(aiChatControllerProvider, (_, _) => _scheduleScrollToEnd());
    final voiceState = ref.watch(voiceSearchControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            if (voiceState.failure != null)
              VoiceFailureBanner(
                message: voiceState.failure!.message,
                onDismiss: () => ref
                    .read(voiceSearchControllerProvider.notifier)
                    .dismissFailure(),
              ),
            Expanded(
              child:
                  aiState.messages.isEmpty && aiState.status != AiStatus.loading
                  ? _buildWelcome(context)
                  : _buildThread(aiState),
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
            _buildInputBar(context, voiceState),
          ],
        ),
      ),
    );
  }

  /// Content entrance flourish — a subtle scale+fade that plays once on
  /// mount. The route transition itself stays native.
  Widget _buildEntrance({required Widget child}) {
    return AiEntranceAnimation(child: child);
  }

  /// A single back control — the page intentionally has no title banner and
  /// no top actions. Returning is via this button, the system back
  /// button/gesture (Android).
  ///
  /// Rendering it through [AppPageHeader] (no title) keeps the control on the
  /// same gutter and geometry as every other pushed page.
  Widget _buildHeader(BuildContext context) {
    return const AppPageHeader();
  }

  Widget _buildWelcome(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _buildEntrance(
      child: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              112,
              AppSpacing.xxl,
              AppSpacing.xxl,
            ),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/TOKI AI.png',
                  width: 96,
                  height: 96,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Hi! Ask me about flights, hotels, and more…',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the chat-first thread: user + assistant bubbles, the result cards
  /// attached to assistant turns, the typing indicator and the follow-up chips.
  Widget _buildThread(AiState aiState) {
    final showTyping = aiState.status == AiStatus.loading;
    final children = <Widget>[];

    for (final message in aiState.messages) {
      final hasText = message.text.trim().isNotEmpty;
      if (hasText) {
        children.add(
          ChatBubble(
            message: message,
            showRetry: message.isUser
                ? false
                : aiState.status == AiStatus.error &&
                      identical(message, aiState.messages.last),
            onRetry: () {
              HapticFeedback.lightImpact();
              ref.read(aiChatControllerProvider.notifier).retry();
            },
          ),
        );
      }
      if (!message.isUser && message.sections.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: message.sections
                  .map(
                    (section) =>
                        _ResultSection(section: section, onItemTap: _openOffer),
                  )
                  .toList(),
            ),
          ),
        );
      }
    }

    if (showTyping) {
      children.add(
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: TypingDots(),
          ),
        ),
      );
    }

    // Follow-up chips after a deterministic result turn.
    final last = aiState.messages.isEmpty ? null : aiState.messages.last;
    if (last != null && !last.isUser && last.sections.isNotEmpty) {
      children.add(_FollowUpRow(onTap: _applyFollowUp));
    }

    final list = ListView(
      controller: _chatScroll,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: children,
    );
    // Entrance flourish only on a fresh conversation.
    return aiState.messages.length <= 1 ? _buildEntrance(child: list) : list;
  }

  Widget _buildInputBar(BuildContext context, VoiceSearchState voiceState) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.xlBorder,
                border: Border.all(color: AppColors.outline),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _textCtrl,
                focusNode: _inputFocus,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                style: TextStyle(
                  fontSize: AppTypography.fontSizeBody,
                  color: scheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.aiSearchSheetHint,
                  hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: AppTypography.fontSizeBody,
                  ),
                  // Same opt-out as the Home pill: the global
                  // inputDecorationTheme must not paint a fill or state
                  // borders here.
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          VoiceMicButton(state: voiceState, onTap: _onMicTap),
          const SizedBox(width: AppSpacing.xs),
          // Send affordance — a bare blue arrow, styled like the Home
          // magnifier and the red mic beside it.
          Semantics(
            button: true,
            label: AppLocalizations.of(context)!.aiSend,
            child: InkResponse(
              onTap: _submit,
              customBorder: const CircleBorder(),
              radius: 24,
              child: const SizedBox(
                width: AppSpacing.minimumTapTarget,
                height: AppSpacing.minimumTapTarget,
                child: Center(
                  child: Icon(
                    Icons.send_rounded,
                    size: 24,
                    color: AppColors.brand,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One deterministic result section — the existing card system, indented to
/// read as part of the assistant turn.
class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.section, required this.onItemTap});

  final HomeSection section;
  final ValueChanged<HomeItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    return HomeSectionWidget(
      section: section,
      onItemTap: onItemTap,
      onFlightTap: onItemTap,
    );
  }
}

/// The follow-up chips (parser-recognized modifiers).
class _FollowUpRow extends StatelessWidget {
  const _FollowUpRow({required this.onTap});

  final ValueChanged<String> onTap;

  static const _chips = <(String, String)>[
    ('أرخص', 'أرخص'),
    ('أفخم', 'أفخم'),
    ('شخصين', 'شخصين'),
  ];

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: _chips
            .map(
              (chip) => ActionChip(
                label: Text(chip.$1),
                backgroundColor: AppColors.surfaceSecondary,
                side: const BorderSide(color: AppColors.outline),
                labelStyle: typography.caption.copyWith(
                  color: AppColors.textPrimary,
                ),
                onPressed: () => onTap(chip.$2),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Chat bubble
// ───────────────────────────────────────────────────────────────────────────

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.showRetry,
    required this.onRetry,
  });

  final AiChatMessage message;
  final bool showRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: AppTypography.fontSizeBody,
                  height: 1.35,
                  color: isUser ? Colors.white : scheme.onSurface,
                ),
              ),
            ),
            // Cached-reply badge.
            if (!isUser && message.fromCache) ...[
              const SizedBox(width: AppSpacing.xs),
              // A quiet marker, not a hue: the palette owns no accent.
              const Icon(Icons.bolt, size: 13, color: AppColors.textSecondary),
            ],
          ],
        ),
        if (showRetry)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context)!.adminRetry),
            ),
          ),
      ],
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        builder: (context, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - v)),
            child: child,
          ),
        ),
        child: Container(
          margin: EdgeInsets.symmetric(
            vertical: AppSpacing.xs,
            horizontal: isUser ? AppSpacing.lg : AppSpacing.lg,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.72,
          ),
          decoration: BoxDecoration(
            gradient: isUser
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.brand, AppColors.brandLight],
                  )
                : null,
            color: isUser ? null : AppColors.surfaceSecondary,
            border: isUser ? null : Border.all(color: AppColors.outline),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isUser ? AppRadius.lg : AppRadius.xs),
              topRight: Radius.circular(isUser ? AppRadius.xs : AppRadius.lg),
              bottomLeft: const Radius.circular(AppRadius.lg),
              bottomRight: const Radius.circular(AppRadius.lg),
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Typing indicator — three staggered bouncing dots.
// ───────────────────────────────────────────────────────────────────────────

class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value - i * 0.22) % 1.0;
            final wave = Curves.easeInOut.transform(
              phase <= 0.5 ? phase * 2 : (1 - phase) * 2,
            );
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              transform: Matrix4.translationValues(0, -4.0 * wave, 0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.35 + 0.55 * wave),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
