import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/features/ai/application/ai_chat_page_providers.dart';
import 'package:tokigo/features/ai/application/ai_state.dart';
import 'package:tokigo/features/ai/domain/ai_chat_message.dart';
import 'package:tokigo/features/ai/presentation/widgets/ai_bubble_icon.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Full-screen AI chat page.
///
/// Opened from the launcher bubble; closed via the header ✕, the system
/// Back button, or Escape (web/desktop). The route uses each platform's
/// native transition, so iOS edge-swipe-back works as usual.
class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key, this.initialPrompt});

  /// The query captured by the AI search box before the chat opened.
  final String? initialPrompt;

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _chatScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // The AI search box hands its query over as a prefilled prompt; the
    // user can edit it before sending, or send as-is.
    _textCtrl.text = widget.initialPrompt ?? '';
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
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

  void _submit() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.mediumImpact();
    // Same submission pathway as AiPromptInput — no duplicated logic.
    ref.read(aiChatControllerProvider.notifier).submit(text);
    _textCtrl.clear();
  }

  void _scheduleScrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScroll.hasClients) return;
      _chatScroll.jumpTo(_chatScroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiChatControllerProvider);
    ref.listen(aiChatControllerProvider, (_, _) => _scheduleScrollToEnd());
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.4)),
            Expanded(
              child: aiState.messages.isEmpty &&
                      aiState.status != AiStatus.loading
                  ? _buildWelcome(context)
                  : _buildMessageList(aiState),
            ),
            Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.4)),
            _buildInputBar(context),
          ],
        ),
      ),
    );
  }

  /// Content entrance flourish — a subtle scale+fade from the bubble's corner
  /// that plays once on mount. The route transition itself stays native so
  /// iOS edge-swipe-back keeps working.
  Widget _buildEntrance({required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (context, v, inner) => Opacity(
        opacity: v,
        child: Transform.scale(
          scale: 0.92 + 0.08 * v,
          alignment: Alignment.bottomRight,
          child: inner,
        ),
      ),
      child: child,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.ai, AppColors.aiLight],
              ),
            ),
            child: const Center(child: AiBubbleIcon(size: 18)),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(
              'TokiGo AI',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
            ),
          ),
          // 2C-C2 — memory controls entry ("What I Know About You").
          Material(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/ai-memory');
              },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.psychology_outlined,
                  size: 20,
                  color: scheme.onSurface,
                  semanticLabel:
                      AppLocalizations.of(context)!.aiMemoryMemoryButton,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Glass circular close button on the RIGHT.
          Material(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).maybePop();
              },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.close, size: 20, color: scheme.onSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _buildEntrance(
      child: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              children: [
                AiBubbleIcon(
                    size: 40, color: AppColors.ai.withValues(alpha: 0.5)),
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

  Widget _buildMessageList(AiState aiState) {
    final showTyping = aiState.status == AiStatus.loading;
    final list = ListView.builder(
      controller: _chatScroll,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      itemCount: aiState.messages.length + (showTyping ? 1 : 0),
      itemBuilder: (context, index) {
        final isTypingItem = index == aiState.messages.length;
        if (isTypingItem) {
          return const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: TypingDots(),
            ),
          );
        }
        final message = aiState.messages[index];
        final isErrorTail = aiState.status == AiStatus.error &&
            index == aiState.messages.length - 1 &&
            !message.isUser;
        return ChatBubble(
          message: message,
          showRetry: isErrorTail,
          onRetry: () {
            HapticFeedback.lightImpact();
            ref.read(aiChatControllerProvider.notifier).retry();
          },
        );
      },
    );
    // The entrance flourish wraps the list only on FIRST build (fresh
    // conversation); afterwards it plays instantly at v=1 and stays inert.
    return _buildEntrance(child: list);
  }

  Widget _buildInputBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: TextField(
                controller: _textCtrl,
                focusNode: _inputFocus,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                style: TextStyle(fontSize: 15, color: scheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Talk to me...',
                  hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Circular gradient send button.
          GestureDetector(
            onTap: _submit,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.ai, AppColors.aiLight],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ai.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ],
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
                  fontSize: 14.5,
                  height: 1.35,
                  color: isUser ? Colors.white : scheme.onSurface,
                ),
              ),
            ),
            // Cached-reply badge.
            if (!isUser && message.fromCache) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.bolt, size: 13, color: Colors.amber.shade700),
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
              child: const Text('Try again'),
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
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
                    colors: [AppColors.ai, AppColors.aiLight],
                  )
                : null,
            color: isUser ? null : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isUser ? 18 : 4),
              topRight: Radius.circular(isUser ? 4 : 18),
              bottomLeft: const Radius.circular(18),
              bottomRight: const Radius.circular(18),
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
            final wave = Curves.easeInOut
                .transform(phase <= 0.5 ? phase * 2 : (1 - phase) * 2);
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              transform: Matrix4.translationValues(0, -4.0 * wave, 0),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
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
