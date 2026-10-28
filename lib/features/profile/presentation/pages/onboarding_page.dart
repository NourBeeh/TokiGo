import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/ui/app_wordmark.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/shared/providers/onboarding_provider.dart';

/// First-launch onboarding — the welcome hero, then two value slides.
///
/// **No photography, by owner decision (2026-10-18):** the app never shows a
/// fabricated image, so the welcome is a brand composition instead of the
/// reference's destination photo — the TokiGo wordmark over the four service
/// plates that already speak the Home identity (a white hairline plate, one
/// neutral shadow, one brand-blue glyph). Nothing here pretends to be
/// inventory: it is the product explaining itself.
///
/// The reference copy is honoured where it maps onto a real flow: "Get started"
/// advances the intro, and "Already have an account? Log in" opens the EXISTING
/// `/auth` page — the welcome screen previously had no way into the account at
/// all, which was the real functional gap against the reference.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _controller = PageController();
  int _page = 0;

  /// The hero is page 0; the two informative slides follow it.
  static const int _heroPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Slide> _slides(AppLocalizations l10n) => <_Slide>[
    // Hero — the product's promise + the four verticals we actually sell.
    _Slide(
      title: l10n.onboardingHeroTitle,
      body: l10n.onboardingHeroBody,
      icons: const <IconData>[
        Icons.flight_takeoff_rounded,
        Icons.hotel_rounded,
        Icons.directions_car_rounded,
        Icons.card_travel_rounded,
      ],
    ),
    _Slide(
      title: l10n.onboardingAiTitle,
      body: l10n.onboardingAiBody,
      icons: const <IconData>[Icons.auto_awesome_rounded],
    ),
    _Slide(
      title: l10n.onboardingBagTitle,
      body: l10n.onboardingBagBody,
      icons: const <IconData>[Icons.luggage_rounded],
    ),
  ];

  void _next(List<_Slide> slides) {
    if (_page < slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  /// Leaves the intro for Home and remembers it, so the first-launch gate never
  /// shows the intro twice.
  void _finish() {
    ref.read(onboardingProvider.notifier).markSeen();
    context.go('/');
  }

  /// "Already have an account? Log in" — the gate redirects an unseen intro
  /// straight back to `/onboarding`, so the flag is set before navigating:
  /// choosing to sign in IS leaving the intro.
  void _logIn() {
    ref.read(onboardingProvider.notifier).markSeen();
    context.push('/auth');
  }

  String _primaryLabel(AppLocalizations l10n, List<_Slide> slides) {
    if (_page == 0) return l10n.onboardingGetStarted;
    if (_page == slides.length - 1) return l10n.onboardingStartExploring;
    return l10n.onboardingNext;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typography = AppTypography.forLight();
    final slides = _slides(l10n);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AiEntranceAnimation(
          child: Column(
            children: <Widget>[
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      l10n.onboardingSkip,
                      style: typography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: slides.length,
                  itemBuilder: (context, index) =>
                      _SlideView(slide: slides[index]),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        for (int i = 0; i < slides.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            // Doc 22 §3.2 — the dots are ⌀6 with a 6pt gap
                            // and the active one is a 16×6 pill.
                            height: 6,
                            width: i == _page ? 16 : 6,
                            decoration: BoxDecoration(
                              // A visible inactive dot: the old
                              // `surfaceTertiary` pill vanished on the white
                              // canvas, so the indicator read as a lone pill.
                              color: i == _page
                                  ? AppColors.brand
                                  : AppColors.outline,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: _primaryLabel(l10n, slides),
                      trailingIcon: Icons.chevron_right_rounded,
                      onPressed: () => _next(slides),
                    ),
                    // The account entry sits under the primary action on the
                    // welcome slide only, exactly like the reference — and the
                    // space is reserved so paging never shifts the button row.
                    Visibility(
                      visible: _page == _heroPage,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        // Doc 22 §3.2 — the account entry is a ghost action of
                        // 44pt, not a second primary button.
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: TextButton(
                            onPressed: _logIn,
                            child: Text.rich(
                              TextSpan(
                                children: <InlineSpan>[
                                  TextSpan(
                                    text: '${l10n.onboardingHaveAccount} ',
                                    style: typography.body.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: l10n.onboardingLogIn,
                                    style: typography.body.copyWith(
                                      color: AppColors.brand,
                                      fontWeight: AppTypography.weightBold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One intro page: a composed visual, then the promise, then the explanation.
///
/// Every page uses the SAME rhythm, so the intro reads as one language — the
/// only difference is the copy.
class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return LayoutBuilder(
      builder: (context, constraints) {
        // The slide scrolls when the type scale or a short screen needs the
        // room — the content never overflows.
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _BrandComposition(icons: slide.icons),
                  const SizedBox(height: AppSpacing.xl),
                  // Doc 22 §3.2 — the title is `display` 36/800, the body
                  // `body` 15/400, both centred.
                  Text(
                    slide.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.display.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    slide.body,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: typography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
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

/// The intro's visual language: the app's own service plates, never a
/// photograph.
///
/// The hero carries the four verticals (in the Home nav strip's tile recipe)
/// over the wordmark; a value slide carries one plate for its single idea.
class _BrandComposition extends StatelessWidget {
  const _BrandComposition({required this.icons});

  final List<IconData> icons;

  @override
  Widget build(BuildContext context) {
    if (icons.length == 1) {
      return _ServicePlate(icon: icons.single, size: 128);
    }
    return Column(
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < icons.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              _ServicePlate(icon: icons[i], size: 56),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppWordmark(
          style: AppTypography.forLight().display.copyWith(
            color: AppColors.wordmarkInk,
          ),
          goStyle: AppTypography.forLight().display.copyWith(
            color: AppColors.brandRed,
          ),
        ),
      ],
    );
  }
}

/// A white hairline plate holding a brand-blue rounded glyph — the exact recipe
/// of the Home nav tiles, so the first screen a user ever sees already speaks
/// the app's surface language.
class _ServicePlate extends StatelessWidget {
  const _ServicePlate({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(
          size > 100 ? AppRadius.xl : AppRadius.lg,
        ),
        border: Border.all(color: AppColors.hairline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: size > 100 ? 56 : 26, color: AppColors.brand),
    );
  }
}

/// One intro page's content (already localized).
class _Slide {
  const _Slide({required this.title, required this.body, required this.icons});

  final String title;
  final String body;

  /// One glyph = a value slide; several = the hero's vertical strip.
  final List<IconData> icons;
}
