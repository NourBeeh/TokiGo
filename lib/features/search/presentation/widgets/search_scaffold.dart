import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:wetravellers/core/theme/app_colors.dart';
import 'package:wetravellers/core/theme/app_radius.dart';
import 'package:wetravellers/core/theme/app_spacing.dart';
import 'package:wetravellers/core/theme/app_typography.dart';

/// The unified search-page scaffold (Wave 2 identity unification).
///
/// One scroll-linked collapsible header for every vertical: the gradient
/// hero + search form collapse smoothly as the results scroll (Booking/
/// Airbnb pattern) instead of the old binary jump. Fields render through
/// [SearchFieldInput] so styling comes from theme tokens, never hardcoded
/// greys.
class SearchScaffold extends StatelessWidget {
  const SearchScaffold({
    super.key,
    required this.hue,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.body,
    this.collapsedTitle,
    this.headerActions,
    this.bottomContent,
  });

  /// Vertical hue (flightHue/hotelHue/carHue/packageHue).
  final Color hue;

  /// Big header title while expanded ("Flights", "Hotels"…).
  final String title;

  /// Supporting line under the title.
  final String subtitle;

  /// The search form rendered inside the collapsing header.
  final Widget form;

  /// Results / content below the header.
  final Widget body;

  /// Compact route/context label shown when collapsed.
  final String? collapsedTitle;

  /// Optional trailing actions in the pinned bar (e.g. view toggle).
  final Widget? headerActions;

  /// Optional content pinned under the app bar (sort/filter row).
  final Widget? bottomContent;

  static const double _collapsedHeight = 64;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            expandedHeight: 320 + topInset,
            collapsedHeight: _collapsedHeight + topInset,
            backgroundColor: hue,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                ),
                tooltip: 'Back',
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/'),
              ),
            ),
            actions: <Widget>[
              if (headerActions != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: AppSpacing.sm,
                  ),
                  child: headerActions!,
                ),
            ],
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                // Scroll-linked progress: 1 expanded → 0 fully collapsed.
                final current = constraints.biggest.height;
                final expandable = 320.0 + topInset;
                final t =
                    ((current - (_collapsedHeight + topInset)) / expandable)
                        .clamp(0.0, 1.0);

                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    // Vertical hue surface — solid, per the design language.
                    ColoredBox(color: hue),
                    // Expanded content fades out while collapsing.
                    Positioned.fill(
                      child: Opacity(
                        opacity: t,
                        child: Offstage(
                          offstage: t < 0.02,
                          child: _ExpandedHeader(
                            title: title,
                            subtitle: subtitle,
                            form: form,
                            topInset: topInset,
                            collapsedHeight: _collapsedHeight,
                          ),
                        ),
                      ),
                    ),
                    // Collapsed compact title fades in near the top.
                    Positioned(
                      top: topInset,
                      left: 56,
                      right: 16,
                      height: _collapsedHeight,
                      child: Opacity(
                        opacity: 1 - t,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            (collapsedTitle ?? title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.bodyLargeMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (bottomContent != null)
            SliverToBoxAdapter(child: bottomContent!),
          SliverToBoxAdapter(child: body),
        ],
      ),
    );
  }
}

class _ExpandedHeader extends StatelessWidget {
  const _ExpandedHeader({
    required this.title,
    required this.subtitle,
    required this.form,
    required this.topInset,
    this.collapsedHeight = 64,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final double topInset;
  final double collapsedHeight;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: collapsedHeight + topInset),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: typography.display.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: typography.body.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            form,
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

/// Unified search form field — theme-token styling for every vertical
/// (replaces the per-page hardcoded-white recipe).
class SearchFieldInput extends StatelessWidget {
  const SearchFieldInput({
    super.key,
    required this.icon,
    required this.hint,
    this.controller,
    this.onTap,
    this.readOnly = false,
    this.suffix,
    this.keyboardType,
  });

  final IconData icon;
  final String hint;
  final TextEditingController? controller;
  final VoidCallback? onTap;
  final bool readOnly;
  final Widget? suffix;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: AppColors.brand),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: readOnly,
                  keyboardType: keyboardType,
                  style: typography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: typography.bodyLarge.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
              if (suffix != null) suffix!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Unified white search CTA rendered under the form.
class SearchSubmitButton extends StatelessWidget {
  const SearchSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.hue,
  });

  final String label;
  final VoidCallback onPressed;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md + 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.search_rounded, size: 20, color: hue),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: typography.bodyLargeMedium.copyWith(color: hue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
