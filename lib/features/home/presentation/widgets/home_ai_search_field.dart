import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/features/home/presentation/home_design_tokens.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Hit target for the trailing mic/send actions. It sits one step below
/// [AppSpacing.minimumTapTarget] (48) so the pill can stay slim while the
/// actions remain a comfortable tap surface.
const double _trailingActionSize = 40;

/// The Home search field — the owner's spec: a white pill (56dp tall, a fully
/// rounded 32 radius, one 1dp `#E0DCD6` border, no shadow) with an accent
/// search glyph on the leading edge and the localized placeholder
/// (`Search destinations, hotels & more`) in `#757575`.
///
/// The pill is deliberately FIXED: it keeps its height, radius, padding, glyph
/// sizes and placeholder at every scroll position — Home no longer compacts its
/// composer when the feed scrolls away.
///
/// The box is multiline: the Enter/keyboard action and the trailing send
/// button both hand the exact trimmed query to [AiChatPage] through the
/// established GoRouter `extra` mechanism, where it is submitted to the
/// existing AI controller. The trailing mic opens the same chat empty, where
/// the live microphone lives.
class HomeAiSearchField extends StatefulWidget {
  const HomeAiSearchField({
    super.key,
    this.accentColor = HomeDesignTokens.accent,
  });

  /// The spec's accent, resolved for the active brightness by the caller.
  final Color accentColor;

  @override
  State<HomeAiSearchField> createState() => _HomeAiSearchFieldState();
}

class _HomeAiSearchFieldState extends State<HomeAiSearchField> {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Duplicate-submission guard.
  bool _submitting = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Opens the unified TokiGo AI chat, optionally seeding the query.
  void _openChat({String? query}) {
    final text = query?.trim() ?? '';
    _focusNode.unfocus();
    if (text.isEmpty) {
      context.push('/ai-chat');
    } else {
      _textCtrl.clear();
      context.push('/ai-chat', extra: text);
    }
  }

  /// Submit the user's trimmed query to the unified chat.
  void _submit() {
    if (_submitting) return;
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      _openChat();
      return;
    }
    _submitting = true;
    HapticFeedback.mediumImpact();
    _openChat(query: text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _submitting = false;
    });
  }

  /// The static hint, forced onto ONE line.
  ///
  /// The placeholder sizes itself from the room the field actually has: it
  /// grows on tablet-class widths and is scaled back down inside the field
  /// whenever the localized string — Arabic or English — would not fit at the
  /// base size. The text is never wrapped, never elided and never painted
  /// outside the field, so the hint reads complete on every screen width.
  Widget _fittedHint(String text, AppTypography typography) {
    // The spec's placeholder ink (#757575) at full opacity — never faded.
    // Doc 17 §3.2 — the placeholder is `body` 15/400.
    final baseStyle = typography.body.copyWith(
      color: HomeDesignTokens.hintOf(context),
    );
    final baseSize = baseStyle.fontSize ?? 15;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Roomy field (tablet-class): a slightly larger placeholder.
        // Still one line — the FittedBox below shrinks it back if needed.
        final style = baseStyle.copyWith(
          fontSize: constraints.maxWidth >= 420 ? baseSize + 3 : baseSize,
        );
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(text, maxLines: 1, softWrap: false, style: style),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    return TapRegion(
      onTapOutside: (_) => _focusNode.unfocus(),
      child: AnimatedContainer(
        key: const ValueKey<String>('home-ai-composer'),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          color: HomeDesignTokens.surfaceOf(context),
          // Fully rounded: a 32 radius on a 56dp-tall box is a stadium.
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: HomeDesignTokens.borderOf(context),
            width: 1,
          ),
          // No elevation/shadow around the search box (audit requirement).
          boxShadow: const <BoxShadow>[],
        ),
        child: Padding(
          // Slim pill: the vertical inset is one step below the horizontal one
          // so the bar reads as a thin, premium search field.
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: <Widget>[
              // The spec's leading search glyph, in the Home accent.
              Icon(
                Icons.search_rounded,
                size: 22,
                color: widget.accentColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              // The editable field with a static, localized hint. The trailing
              // send action submits the current query.
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('home-ai-composer-field'),
                  controller: _textCtrl,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    // The static hint is a WIDGET, not hintText: it must always
                    // read as ONE line, so it scales with the room the field
                    // actually has (see [_fittedHint]).
                    hint: _fittedHint(l10n.homeSearchHint, typography),
                    // Fully opt out of the global inputDecorationTheme: its
                    // filled off-white fill and its state borders (the blue
                    // brand focusedBorder) must never repaint this pill.
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                  ),
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                  minLines: 1,
                  // Multiline where the text needs it; the pill grows in place
                  // (the composer is an overlay, so the page never jumps).
                  maxLines: 4,
                  style: typography.bodyLarge.copyWith(
                    color: context.tokigoColors.textPrimary,
                  ),
                  autofocus: false,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // Voice — opens the chat where the live microphone lives.
              Semantics(
                button: true,
                label: l10n.voiceSearch,
                child: InkResponse(
                  onTap: () => _openChat(),
                  customBorder: const CircleBorder(),
                  radius: 22,
                  child: SizedBox(
                    width: _trailingActionSize,
                    height: _trailingActionSize,
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: widget.accentColor.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(
                          width: 34,
                          height: 34,
                          child: Center(
                            child: Icon(
                              Icons.mic_rounded,
                              size: 19,
                              color: widget.accentColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Send is the solid ink primary action. It uses the send glyph
              // (not a second magnifier) because the job here is to submit the
              // typed message to the AI, not to open a picker.
              Semantics(
                button: true,
                label: l10n.aiSend,
                child: InkResponse(
                  key: const ValueKey<String>('home-ai-composer-send'),
                  onTap: _submit,
                  customBorder: const CircleBorder(),
                  radius: 22,
                  child: SizedBox(
                    width: _trailingActionSize,
                    height: _trailingActionSize,
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: widget.accentColor,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(
                          width: 34,
                          height: 34,
                          child: Center(
                            child: Icon(
                              Icons.send_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}
