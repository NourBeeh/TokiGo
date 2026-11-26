import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/app/widgets/home_nav_buttons.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/features/home/presentation/home_design_tokens.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tokigo/core/geo/location_prompt.dart';
import 'package:tokigo/core/ui/app_wordmark.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/pressable.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/shared/providers/onboarding_provider.dart';
import 'package:tokigo/core/ui/directional_icons.dart';

/// First-launch onboarding — the welcome hero, then two value slides.
///
/// **No photography, by owner decision (2026-10-18):** the app never shows a
/// fabricated image, so the welcome is a brand composition instead of the
/// reference's destination photo — the TokiGo wordmark over the SAME four
/// service buttons as Home, built from [homeActionDefinitions] and
/// [HomeActionGlyph]. Their 68dp tiles, 16dp gaps and glyph recipe come from
/// Home's action bar, so the first screen a traveller sees cannot drift from
/// the buttons inside the app. Nothing here pretends to be inventory: it is
/// the product explaining itself.
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
      // One source of truth: these are the exact definitions Home renders.
      actions: homeActionDefinitions(l10n),
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
    _Slide(
      title: l10n.localeName == 'ar' ? 'الأذونات' : 'Permissions',
      body: l10n.locationPromptBody,
      icons: const <IconData>[
        Icons.location_on_rounded,
        Icons.notifications_rounded,
      ],
    ),
  ];

  Future<void> _next(List<_Slide> slides) async {
    if (_page < slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      await _requestPermissions();
      _finish();
    }
  }

  Future<void> _requestPermissions() async {
    // Location first, from this dedicated intro step: the OS dialog is raised
    // here and nowhere else on launch. "When in use" only (the app's
    // Info.plist carries NSLocationWhenInUseUsageDescription and the Android
    // manifest has no background location), and a denial never blocks —
    // `requestLocationAccess` simply leaves the city to the IP fallback so the
    // traveller can pick a city manually later.
    await requestLocationAccess(ref);

    // Notifications follow, as before.
    try {
      await Permission.notification.request();
    } catch (_) {}
  }

  /// Leaves the intro for Home and remembers it, so the first-launch gate
  /// never shows the intro twice.
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
    if (_page == slides.length - 1)
      return l10n.localeName == 'ar' ? 'السماح' : 'Grant permissions';
    return l10n.onboardingNext;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typography = AppTypography.forLight();
    final slides = _slides(l10n);

    return Scaffold(
      backgroundColor: context.tokigoColors.background,
      body: SafeArea(
        child: AiEntranceAnimation(
          child: Column(
            children: <Widget>[
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Pressable.wrap(
                    child: TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(
                          64,
                          AppSpacing.minimumTapTarget,
                        ),
                      ),
                      child: Text(
                        l10n.onboardingSkip,
                        style: typography.body.copyWith(
                          color: context.tokigoColors.textSecondary,
                        ),
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
                              // A visible inactive dot: `textTertiary` clears
                              // 3:1 on both canvases (the old `outline` did
                              // not), so the indicator never reads as a lone
                              // pill.
                              color: i == _page
                                  ? context.tokigoColors.primary
                                  : context.tokigoColors.textTertiary,
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
                      trailingIcon: DirectionalIcons.chevron(context),
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
                        // Doc 22 §3.2 — the account entry is a ghost action,
                        // not a second primary button, and clears the 48pt
                        // minimum tap target.
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: AppSpacing.minimumTapTarget,
                          ),
                          child: Pressable.wrap(
                            child: TextButton(
                              onPressed: _logIn,
                              child: Text.rich(
                                TextSpan(
                                  children: <InlineSpan>[
                                    TextSpan(
                                      text: '${l10n.onboardingHaveAccount} ',
                                      style: typography.body.copyWith(
                                        color:
                                            context.tokigoColors.textSecondary,
                                      ),
                                    ),
                                    TextSpan(
                                      text: l10n.onboardingLogIn,
                                      style: typography.body.copyWith(
                                        color: context.tokigoColors.brand,
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
                  _BrandComposition(actions: slide.actions, icons: slide.icons),
                  const SizedBox(height: AppSpacing.xl),
                  // Doc 22 §3.2 — the title is `display` 36/800, the body
                  // `body` 15/400, both centred.
                  Text(
                    slide.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.display.copyWith(
                      color: context.tokigoColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    slide.body,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: typography.body.copyWith(
                      color: context.tokigoColors.textSecondary,
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
/// The hero reuses Home's action definitions, [HomeActionBar.gap] and
/// [HomeActionTile.height] so its four buttons are literally the same size,
/// spacing and glyphs as the buttons inside the app. Value slides keep the
/// same plate recipe for their single idea.
class _BrandComposition extends StatelessWidget {
  const _BrandComposition({required this.actions, required this.icons});

  /// Home's four service definitions — empty on the value slides.
  final List<HomeActionDefinition> actions;

  /// Standalone glyphs for the AI, bag and permission slides.
  final List<IconData> icons;

  @override
  Widget build(BuildContext context) {
    if (actions.isNotEmpty) {
      return Column(
        children: <Widget>[
          _HomeServiceRow(actions: actions),
          const SizedBox(height: AppSpacing.xl),
          AppWordmark(base: AppTypography.forLight().display),
        ],
      );
    }
    if (icons.length == 1) {
      return _ServicePlate(icon: icons.single, size: 128);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < icons.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: HomeActionBar.gap),
          _ServicePlate(icon: icons[i], size: HomeActionTile.height),
        ],
      ],
    );
  }
}

/// The first screen's four-up, using Home's exact tile geometry: 68dp squares
/// capped at [HomeActionTile.height], separated by [HomeActionBar.gap]. Narrow
/// phones shrink the tiles evenly instead of clipping; wider ones centre the
/// 320dp strip (4 × 68 + 3 × 16).
class _HomeServiceRow extends StatelessWidget {
  const _HomeServiceRow({required this.actions});

  final List<HomeActionDefinition> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gap = HomeActionBar.gap;
        final double tileWidth =
            ((constraints.maxWidth - gap * (actions.length - 1)) /
                    actions.length)
                .clamp(0.0, HomeActionTile.height)
                .toDouble();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < actions.length; i++) ...<Widget>[
              if (i > 0) SizedBox(width: gap),
              _ServicePlate(
                key: ValueKey<String>(
                  'onboarding-service-${actions[i].action.id}',
                ),
                definition: actions[i],
                size: tileWidth,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A flat hairline plate holding the same glyph Home renders.
///
/// [HomeActionGlyph] owns the parasol asset and the Material icon sizes, so
/// onboarding cannot fall back to a stale copy of the service icons.
class _ServicePlate extends StatelessWidget {
  const _ServicePlate({
    super.key,
    this.icon,
    this.definition,
    required this.size,
  });

  final IconData? icon;
  final HomeActionDefinition? definition;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool large = size > 100;
    return Container(
      key: key,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HomeDesignTokens.surfaceOf(context),
        borderRadius: large ? AppRadius.xlBorder : AppRadius.lgBorder,
        border: Border.all(color: HomeDesignTokens.borderOf(context)),
        // Home's quick-action tiles are flat; no second shadow language here.
        boxShadow: const <BoxShadow>[],
      ),
      child: definition != null
          ? HomeActionGlyph(
              definition: definition!,
              color: HomeDesignTokens.accentOf(context),
            )
          : SizedBox(
              height: HomeActionTile.iconSlotHeight,
              child: Align(
                alignment: large ? Alignment.center : Alignment.bottomCenter,
                child: Icon(
                  icon,
                  size: large ? 56 : HomeActionTile.iconSize,
                  color: HomeDesignTokens.accentOf(context),
                ),
              ),
            ),
    );
  }
}

/// One intro page's content (already localized).
class _Slide {
  const _Slide({
    required this.title,
    required this.body,
    this.actions = const <HomeActionDefinition>[],
    this.icons = const <IconData>[],
  });

  final String title;
  final String body;

  /// Home's service definitions — only the hero slide carries four.
  final List<HomeActionDefinition> actions;

  /// Standalone glyphs for the value slides.
  final List<IconData> icons;
}
