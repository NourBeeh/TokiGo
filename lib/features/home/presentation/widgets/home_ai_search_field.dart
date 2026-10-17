import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:wetravellers/core/theme/app_colors.dart';
import 'package:wetravellers/core/theme/app_radius.dart';
import 'package:wetravellers/core/theme/app_spacing.dart';
import 'package:wetravellers/core/theme/app_typography.dart';
import 'package:wetravellers/l10n/app_localizations.dart';

/// Hero tag shared by the closed Home pill and the opened search header.
const String kAiSmartSearchHeroTag = 'ai-smart-search-pill';

/// Smart AI search field pinned in the Home header.
///
/// A Google-grade premium search bar: a stark-white pill with the AI
/// sparkle on the leading edge, a soft violet search circle on the
/// trailing edge, wrapped in a slow rotating light comet — a premium sweep
/// of AI violet and brand indigo travelling around the pill border with a
/// quiet breathing glow behind it.
///
/// The pill is a genuinely editable TextField: the user types directly in
/// Home and submits with either the trailing search/send icon or Enter.
/// Both actions share one submission handler and hand the exact trimmed
/// query to the AI chat page ([AiChatPage]) via the established
/// GoRouter `extra` mechanism.
class HomeAiSearchField extends StatefulWidget {
  const HomeAiSearchField({super.key});

  @override
  State<HomeAiSearchField> createState() => _HomeAiSearchFieldState();
}

class _HomeAiSearchFieldState extends State<HomeAiSearchField>
    with SingleTickerProviderStateMixin {
  static const Duration _typeTick = Duration(milliseconds: 45);
  static const Duration _eraseTick = Duration(milliseconds: 25);
  static const Duration _holdLine = Duration(seconds: 2);

  late final TextEditingController _textCtrl;
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _auraController;
  late final Animation<double> _aura;

  // Typewriter hint — driven live into the TextField's decoration.
  List<String> _phrases = const [];
  int _phraseIndex = 0;
  int _charCount = 0;
  bool _erasing = false;
  Timer? _timer;

  // Duplicate-submission guard.
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController();
    _auraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat();
    _aura = CurvedAnimation(parent: _auraController, curve: Curves.linear);
    _phrases = const <String>[];
    _scheduleTick(_typeTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    final phrases = <String>[
      l10n.aiHintPhrase1,
      l10n.aiHintPhrase2,
      l10n.aiHintPhrase3,
    ];
    // Locale changed mid-flight — restart the current line with the new
    // language's phrases (keeps the index so rotation stays seamless).
    if (listEquals(_phrases, phrases)) return;
    final restart = _phrases.isNotEmpty;
    _phrases = phrases;
    if (restart) {
      _charCount = 0;
      _erasing = false;
      _scheduleTick(_typeTick);
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    _auraController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleTick(Duration interval) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final phrase = _phrases[_phraseIndex % _phrases.length];
    if (!_erasing) {
      if (_charCount < phrase.length) {
        _charCount++;
        if (_charCount == 1) {
          // Typing just began — full typing cadence (in case we were in
          // hold/erase cadence before).
          _scheduleTick(_typeTick);
        }
        setState(() {});
      } else {
        // Line complete — hold it before wiping.
        _scheduleTick(_holdLine);
        _erasing = true;
      }
    } else {
      if (_charCount > 0) {
        _charCount--;
        if (_charCount == phrase.length - 1) {
          // Wiping just began — switch to the faster erase cadence.
          _scheduleTick(_eraseTick);
        }
        setState(() {});
      } else {
        // Wiped — advance to the next phrase and start typing it.
        _phraseIndex = (_phraseIndex + 1) % _phrases.length;
        _erasing = false;
        _scheduleTick(_typeTick);
        setState(() {});
      }
    }
  }

  /// The live typewriter phrase shown as the TextField's hint text.
  String get _hintPhrase {
    if (_phrases.isEmpty) return '';
    final phrase = _phrases[_phraseIndex % _phrases.length];
    return phrase.substring(0, _charCount.clamp(0, phrase.length));
  }

  /// Submit the user's trimmed query to the AI chat page.
  ///
  /// Both the search icon and the Enter key route through this single
  /// handler. The field is cleared on submit and the duplicate guard is
  /// reset on the next frame, so the same query can never be submitted
  /// twice and legitimate follow-up queries are unaffected.
  void _submit() {
    if (_submitting) return;
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _submitting = true;
    HapticFeedback.mediumImpact();
    // Dismiss the keyboard so the chat page does not open covered.
    _focusNode.unfocus();
    // Clear the field immediately (keeps the same query from being
    // resubmitted by a repeat tap).
    _textCtrl.clear();
    // Allow a brand-new query to be submitted on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _submitting = false;
    });
    context.push('/ai-chat', extra: text);
  }

  /// Open the full smart-search surface (preserves the existing launcher
  /// entry point for the universal search surface).
  void _openSmartSearch() {
    if (!mounted) return;
    context.push('/smart-search');
  }

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      label: l10n.aiSearchHint,
      child: AnimatedBuilder(
        animation: _aura,
        builder: (context, _) {
          // Quiet breathing glow behind the pill — same restrained language
          // the retired AI centre button used. Deliberately OUTSIDE the
          // hero: the glow keeps breathing in Home while the pill flies.
          final breath = 0.06 + _aura.value * 0.06;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.ai.withValues(alpha: breath),
                  blurRadius: 16 + _aura.value * 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _RotatingAuraBorder(
              aura: _aura,
              // Quiet static hairline behind the comet so the field keeps
              // a visible outline on every frame.
              baseBorder: AppColors.ai.withValues(alpha: 0.22),
              child: Hero(
                tag: kAiSmartSearchHeroTag,
                // The closed pill leaves Home entirely while flying.
                placeholderBuilder: (_, __, ___) => const SizedBox.shrink(),
                flightShuttleBuilder: _pillShuttle,
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: <Widget>[
                        const SizedBox(width: AppSpacing.xs),
                        // Leading sparkle — tap to open the full smart
                        // search surface (the established entry point).
                        InkWell(
                          onTap: _openSmartSearch,
                          customBorder: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(AppSpacing.xs),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              size: 24,
                              color: AppColors.ai,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        // The editable field. The typewriter hint is fed into
                        // the TextField's decoration so the user types
                        // directly in Home.
                        Expanded(
                          child: TextField(
                            controller: _textCtrl,
                            focusNode: _focusNode,
                            decoration: InputDecoration(
                              hintText: _hintPhrase,
                              hintStyle: typography.bodyLarge.copyWith(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _submit(),
                            style: typography.bodyLarge.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            autofocus: false,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        // Search/send affordance — interactive (single shared
                        // submission path with the Enter key).
                        GestureDetector(
                          onTap: _submit,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.aiContainer,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: AppColors.ai,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        // Voice search placeholder — kept disabled (US-3+
                        // extension point), never interactive.
                        ExcludeSemantics(
                          child: Semantics(
                            button: true,
                            enabled: false,
                            label: 'Voice search — coming soon',
                            child: const SizedBox(
                              width: 36,
                              height: 36,
                              child: Center(
                                child: Icon(
                                  Icons.mic_none_rounded,
                                  size: 20,
                                  color: AppColors.textTertiary,
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
              ),
            ),
          );
        },
      ),
    );
  }

  /// The in-flight capsule — pixel-identical to the expanded header the
  /// flight lands into (US-1 handoff contract): same surfaceSecondary
  /// background, same aiContainer hairline, same leading sparkle at the
  /// same 24px + md gap. The handoff at t=1 is a pure size change with
  /// zero style swap — no snap.
  Widget _pillShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Opacity(
          opacity: Curves.easeIn.transform(
            animation.value.clamp(0.0, 1.0),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: AppRadius.pillBorder,
              border: Border.all(color: AppColors.aiContainer),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: const Row(
                children: <Widget>[
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 24,
                    color: AppColors.ai,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A light comet travelling around the pill border.
///
/// A rounded-rect ring slightly larger than the child is painted through a
/// rotating [SweepGradient] via [ShaderMask]: most of the sweep is
/// transparent and a short arc blends AI violet into brand indigo, so the
/// visible border light orbits the field slowly instead of flashing. The
/// ring sits ABOVE the hero child with pointer events ignored, so the
/// comet keeps orbiting in Home while the pill itself is free to fly.
class _RotatingAuraBorder extends StatelessWidget {
  const _RotatingAuraBorder({
    required this.aura,
    required this.baseBorder,
    required this.child,
  });

  final Animation<double> aura;
  final Color baseBorder;
  final Widget child;

  static const double _borderWidth = 2;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        // Static hairline — the pill's resting outline, wrapped around
        // the hero so the pill keeps its shape while idle in Home.
        Container(
          padding: const EdgeInsets.all(_borderWidth),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: baseBorder, width: _borderWidth),
          ),
          child: child,
        ),
        // The travelling light comet, masked on top of the same ring shape.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: aura,
              builder: (context, _) {
                final rotation = aura.value * 2 * 3.141592653589793;
                return ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (bounds) {
                    return SweepGradient(
                      startAngle: -1.5707963267948966,
                      endAngle: 4.71238898038469,
                      colors: const <Color>[
                        Color(0x00000000),
                        Color(0x00000000),
                        AppColors.ai,
                        AppColors.brand,
                        AppColors.aiLight,
                        Color(0x00000000),
                        Color(0x00000000),
                      ],
                      stops: const <double>[0.0, 0.52, 0.62, 0.72, 0.82, 0.92, 1.0],
                      transform: GradientRotation(rotation),
                    ).createShader(bounds);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: AppColors.ai,
                        width: _borderWidth,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
