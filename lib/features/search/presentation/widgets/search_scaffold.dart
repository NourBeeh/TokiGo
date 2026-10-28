import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/detached_back_button.dart';
import 'package:tokigo/core/widgets/page_header.dart';

/// The unified search-page scaffold (identity unification).
///
/// Every vertical now shares ONE identity with the Groups discovery
/// surfaces: the plain canvas, the shared [AppPageHeader], and the search form
/// rendered beneath it with the same surface/outline card language. There is
/// no per-vertical coloured header any more — the vertical hue lives inside
/// the result cards, not the page chrome.
///
/// The form controls ([SearchFieldInput], [SearchStepperInput],
/// [SearchSegmentedControl], [SearchChoiceChip], [SearchSubmitButton]) are
/// shared so every vertical renders the exact same controls instead of
/// re-implementing them.
/// Above this many results a page must render its list with a lazy sliver
/// instead of a [Column] of cards. Building every card up front also builds
/// every card image, which is what pushed low-RAM Android phones into the Low
/// Memory Killer on long hotel result lists.
///
/// Small lists stay eager on purpose: the difference is invisible, and the
/// existing page tests/captures can keep asserting on the whole list.
const int kSearchLazyResultsThreshold = 12;

class SearchScaffold extends StatelessWidget {
  const SearchScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.body,
    this.headerActions,
    this.bottomContent,
    this.bodySlivers,
  });

  /// Big header title ("Flights", "Hotels"…).
  final String title;

  /// Supporting line under the title.
  final String subtitle;

  /// The search form rendered under the header.
  final Widget form;

  /// Results / content below the form.
  final Widget body;

  /// Optional lazy slivers replacing [body] (which is then ignored).
  ///
  /// A page with a long result list passes its header bar, a `SliverList`
  /// builder and its footer here so off-screen cards are never built — and
  /// their images never loaded — until they scroll into view.
  final List<Widget>? bodySlivers;

  /// Optional trailing actions in the header (e.g. view toggle).
  final Widget? headerActions;

  /// Optional content pinned under the form (sort/filter row).
  final Widget? bottomContent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        // The header no longer draws the back control: the detaching one does,
        // and it stays reachable once the header scrolls away.
        child: DetachedBackButton(
          child: AiEntranceAnimation(
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: AppPageHeader(
                    title: title,
                    subtitle: subtitle,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[?headerActions],
                    ),
                    showBackButton: false,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(child: form),
                ),
                if (bottomContent != null)
                  SliverToBoxAdapter(child: bottomContent!),
                if (bodySlivers != null)
                  ...bodySlivers!
                else
                  SliverToBoxAdapter(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Unified search form field — theme-token styling for every vertical
/// (surface fill + hairline outline, matching the card language).
///
/// The optional [label] is the small caption shown above the value ("From",
/// "Departure") so an untouched form still reads as a labelled form instead of
/// a row of anonymous empty boxes. [value] renders a plain read-out instead of
/// an editable field — used when the API receives a stable code but the screen
/// should show a readable name.
class SearchFieldInput extends StatelessWidget {
  const SearchFieldInput({
    super.key,
    required this.icon,
    required this.hint,
    this.label,
    this.value,
    this.controller,
    this.onTap,
    this.readOnly = false,
    this.suffix,
    this.keyboardType,
  });

  final IconData icon;
  final String hint;

  /// Small caption rendered above the value (optional).
  final String? label;

  /// Read-out shown instead of the text field (optional).
  final String? value;

  final TextEditingController? controller;
  final VoidCallback? onTap;
  final bool readOnly;
  final Widget? suffix;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final label = this.label;
    final value = this.value;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdBorder,
        side: const BorderSide(color: AppColors.outline),
      ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (label != null) ...<Widget>[
                      Text(
                        label,
                        style: typography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    if (value != null)
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      )
                    else
                      // A read-only field with a picker behind it must not
                      // swallow the tap: the embedded TextField's own gesture
                      // would win and the card's onTap would never fire (the
                      // field looked dead on the device).
                      IgnorePointer(
                        ignoring: readOnly && onTap != null,
                        child: TextField(
                          controller: controller,
                          readOnly: readOnly,
                          keyboardType: keyboardType,
                          style: typography.bodyLarge.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            // The card itself is the field chrome: the
                            // embedded input must not re-draw the theme's
                            // filled box.
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: hint,
                            hintStyle: typography.bodyLarge.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ?suffix,
            ],
          ),
        ),
      ),
    );
  }
}

/// Unified segmented single-select control (trip type…) — one grey track with
/// the selected segment filled in brand, so a choice reads as ONE control
/// instead of loose chips. Only real capabilities may be offered as segments.
class SearchSegmentedControl<T> extends StatelessWidget {
  const SearchSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: <Widget>[
          for (final option in options)
            Expanded(
              child: Material(
                color: option == selected
                    ? AppColors.brand
                    : Colors.transparent,
                borderRadius: AppRadius.pillBorder,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onSelected(option),
                  child: SizedBox(
                    height: 36,
                    child: Center(
                      child: Text(
                        labelOf(option),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.captionSemibold.copyWith(
                          color: option == selected
                              ? AppColors.onBrand
                              : AppColors.textSecondary,
                        ),
                      ),
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

/// Unified counter input (passengers / guests / rooms / trip length) —
/// one shared recipe so every vertical's stepper is identical.
class SearchStepperInput extends StatelessWidget {
  const SearchStepperInput({
    super.key,
    required this.icon,
    required this.label,
    required this.onDecrement,
    required this.onIncrement,
    this.count,
  });

  final IconData icon;
  final String label;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  /// Optional numeric readout shown between the −/+ buttons.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdBorder,
        side: const BorderSide(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
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
              child: Text(
                label,
                style: typography.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            _StepperButton(Icons.remove_rounded, onDecrement),
            if (count != null) ...<Widget>[
              const SizedBox(width: AppSpacing.md),
              Text(
                '$count',
                style: typography.bodyLargeMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
            const SizedBox(width: AppSpacing.md),
            _StepperButton(Icons.add_rounded, onIncrement),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton(this.icon, this.onTap);

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandContainer,
      borderRadius: BorderRadius.circular(AppRadius.xs),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 18, color: AppColors.brand),
        ),
      ),
    );
  }
}

/// Unified single-select form chip (trip type, transmission…) — matches the
/// sort-chip language: brand fill when selected, surface/outline otherwise.
class SearchChoiceChip extends StatelessWidget {
  const SearchChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Optional leading glyph (a Material icon — the bundled fonts have no star
  /// character, so a text glyph would render as tofu).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final foreground = selected ? AppColors.onBrand : AppColors.textSecondary;
    final icon = this.icon;
    return Material(
      color: selected ? AppColors.brand : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.pillBorder,
        side: BorderSide(color: selected ? AppColors.brand : AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: AppSpacing.xxs),
              ],
              Text(
                label,
                style: typography.captionSemibold.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Unified search CTA rendered under the form — the shared primary button kit,
/// so every vertical's submit action matches the rest of the app.
class SearchSubmitButton extends StatelessWidget {
  const SearchSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppButton(
        label: label,
        onPressed: onPressed,
        leadingIcon: Icons.search_rounded,
      ),
    );
  }
}
