import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/shared/providers/onboarding_provider.dart';

/// First-launch onboarding — three premium intro slides shown once.
///
/// Completion is persisted via [onboardingProvider] (Hive-backed flag).
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<_Slide> _slides = <_Slide>[
    _Slide(
      title: 'Book every part of your trip',
      body: 'Flights, hotels, cars and curated packages — one app, one checkout.',
      icon: Icons.flight_takeoff_rounded,
      hue: AppColors.flightHue,
    ),
    _Slide(
      title: 'Your AI travel companion',
      body: 'Ask anything: plan a weekend, find cheaper alternatives, compare offers.',
      icon: Icons.auto_awesome_rounded,
      hue: AppColors.ai,
    ),
    _Slide(
      title: 'All your trips in one bag',
      body: 'Every booking lands in one place — with readiness checks and price watches.',
      icon: Icons.luggage_rounded,
      hue: AppColors.carHue,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    ref.read(onboardingProvider.notifier).markSeen();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Skip',
                    style: typography.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                            color: slide.hue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(slide.icon, size: 56, color: slide.hue),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: typography.headline.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          slide.body,
                          textAlign: TextAlign.center,
                          style: typography.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (int i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          height: 8,
                          width: i == _page ? 28 : 8,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? AppColors.brand
                                : AppColors.surfaceTertiary,
                            borderRadius: BorderRadius.circular(
                              AppRadius.pill,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: isLast ? 'Start exploring' : 'Next',
                    trailingIcon: Icons.chevron_right_rounded,
                    onPressed: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Slide {
  const _Slide({
    required this.title,
    required this.body,
    required this.icon,
    required this.hue,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color hue;
}
