import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Compact hit target for the trailing mic/search actions. It sits one step
/// below [AppSpacing.minimumTapTarget] (48) so the pill can stay slim while
/// the actions remain a comfortable tap surface.
const double _trailingActionSize = 40;

/// The Home search field — a clean, Bunny-Search-style rounded rectangle: a
/// crisp white fill, a 0.5px hairline border that never changes on focus, the
/// TOKI AI mark on the leading edge and a quiet search affordance on the
/// trailing edge. No rotating aura, no breathing glow, no typewriter — the
/// field reads as a calm, premium search bar that opens the unified TokiGo AI
/// chat.
///
/// The box is multiline: Enter inserts a newline. Submission happens only via
/// the trailing search/send action (or the leading sparkle, which opens the
/// chat empty). Both hand the exact trimmed query to [AiChatPage] via the
/// established GoRouter `extra` mechanism, where it is submitted to the AI on
/// open. The static hint always renders on ONE line — it auto-sizes to the
/// room the field has instead of wrapping — see [_HomeAiSearchFieldState].
class HomeAiSearchField extends StatefulWidget {
  const HomeAiSearchField({super.key, this.accentColor = AppColors.brand});

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
    // Full-opacity textSecondary (5.0:1 on the warm canvas). The previous
    // `withValues(alpha: 0.7)` blended it to ≈#979797 — 2.9:1, below WCAG AA
    // for body text. The placeholder must stay legible, not fade away.
    // Doc 17 §3.2 — the placeholder is `body` 15/400.
    final baseStyle = typography.body.copyWith(color: AppColors.textSecondary);
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

    return Container(
      // A raised white search surface stands out against the seasonal canvas.
      constraints: const BoxConstraints(minHeight: 46),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: AppColors.hairline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: widget.accentColor.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        // Slim pill: the vertical inset is one step below the horizontal one
        // so the bar reads as a thin, premium search field.
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: <Widget>[
            // The editable field with a static, localized hint. The trailing
            // search/send action submits the current query.
            Expanded(
              child: TextField(
                controller: _textCtrl,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  // The static hint is a WIDGET, not hintText: it must always
                  // read as ONE line, so it scales with the room the field
                  // actually has (see [_fittedHint]).
                  hint: _fittedHint(l10n.aiSearchHint, typography),
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
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submit(),
                minLines: 1,
                maxLines: 1,
                style: typography.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
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
            // Search / send is the solid season-colored primary action.
            Semantics(
              button: true,
              label: l10n.aiSend,
              child: InkResponse(
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
                            Icons.search_rounded,
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
    );
  }
}
