import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/app_back_button.dart';
import 'package:tokigo/core/widgets/app_icon_action.dart';
import 'package:tokigo/core/widgets/cards/card.dart';
import 'package:tokigo/core/widgets/pressable.dart';
import 'package:tokigo/core/widgets/sticky_cta_bar.dart';
import 'package:tokigo/features/home/presentation/destination_localization.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The information page a Discover city tile opens.
///
/// It is deliberately a CITY page, not a pre-filtered search: the traveller
/// tapped a place, so the surface explains the place and hands off to its
/// stays. Everything it shows comes from the tapped [HomeItem] — the photo,
/// the name, the region and the description the provider actually sent. When a
/// fact is missing the page omits it rather than inventing it (no fake
/// overview, no fake stay count).
///
/// **Composition (2026-11 redesign):** the expanded city is card G, the same
/// detail surface the hotel page uses — a full-bleed hero at 52% of the
/// viewport (44% under 480pt), a sheet biting 24px up into it, the city's
/// identity at the top of the sheet, its story in a quiet inner panel, and the
/// dark pinned bar carrying the real region / stay count plus the one action.
/// The city card and the hotel card therefore land on the same page shape
/// instead of two unrelated layouts.
class CityPage extends StatelessWidget {
  const CityPage({super.key, this.city});

  /// The tapped destination. Null (or any other extra type) means the route
  /// was opened without its data — the page says so instead of guessing a city.
  final HomeItem? city;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final HomeItem? item = city;

    if (item == null || item.title.trim().isEmpty) {
      return Scaffold(
        backgroundColor: context.tokigoColors.background,
        body: SafeArea(
          child: AppMessageState(
            icon: Icons.location_off_outlined,
            title: l10n?.homeCityNotFoundTitle ?? 'City not found',
            body:
                l10n?.homeCityNotFoundBody ??
                'Go back to Discover and choose a city.',
            actionLabel: l10n?.back ?? 'Back',
            onAction: () => context.canPop() ? context.pop() : context.go('/'),
          ),
        ),
      );
    }

    final typography = AppTypography.forLight();
    final String sourceTitle = item.title.trim();
    final String languageCode = Localizations.localeOf(context).languageCode;
    final String title = localizedDestinationText(
      item,
      DestinationTextField.title,
      l10n: l10n,
      languageCode: languageCode,
    ).trim();
    final String region = localizedDestinationText(
      item,
      DestinationTextField.region,
      l10n: l10n,
      languageCode: languageCode,
    );
    final String? description = _nonEmpty(
      localizedDestinationText(
        item,
        DestinationTextField.description,
        l10n: l10n,
        languageCode: languageCode,
      ),
    );
    final String? imageUrl = _nonEmpty(item.imageUrl);
    final String? photoCredit = _nonEmpty(
      item.metadata['imageCredit']?.toString(),
    );
    final String? photoLicense = _nonEmpty(
      item.metadata['imageLicense']?.toString(),
    );
    final String? photoSource = _nonEmpty(
      item.metadata['imageSource']?.toString(),
    );
    final int? staysCount = _staysCount(item);
    final String? staysText = staysCount == null
        ? null
        : (l10n?.cityStaysCount(staysCount) ??
              (staysCount == 1 ? '1 stay' : '$staysCount stays'));
    final String contextLine = <String>[
      if (region.isNotEmpty) region,
      ?staysText,
    ].join(' · ');

    return Scaffold(
      backgroundColor: context.tokigoColors.background,
      body: AiEntranceAnimation(
        child: Stack(
          children: <Widget>[
            CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: AppHeroSheet(
                    media: _CityHero(imageUrl: imageUrl, title: title),
                    // The sheet owns its own horizontal rhythm so the hero can
                    // stay full-bleed while the copy shares the page's gutter.
                    sheetPadding: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.lg,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: typography.headline.copyWith(
                              color: context.tokigoColors.textPrimary,
                            ),
                          ),
                          if (region.isNotEmpty) ...<Widget>[
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.place_outlined,
                                  size: 16,
                                  color: context.tokigoColors.textSecondary,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    region,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: typography.body.copyWith(
                                      color: context.tokigoColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (staysText != null) ...<Widget>[
                            const SizedBox(height: AppSpacing.md),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TravelMetaChip(
                                label: staysText,
                                icon: Icons.bed_outlined,
                                emphasized: true,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          _CityAbout(
                            title: l10n?.homeCityAbout ?? 'About the city',
                            body:
                                description ??
                                (l10n?.homeCityOverviewFallback(title) ??
                                    'Find your stay in $title and explore '
                                        'everything the city has to offer.'),
                          ),
                          if (photoCredit != null) ...<Widget>[
                            const SizedBox(height: AppSpacing.lg),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: context.tokigoColors.hairline,
                            ),
                            _PhotoCredit(
                              credit: photoCredit,
                              license: photoLicense,
                              source: photoSource,
                            ),
                          ],
                          const SizedBox(height: 140),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // The page's own back control stays visible at every scroll offset
            // (a pushed page always offers a visible back button).
            Positioned(
              top: 0,
              left: AppSpacing.md,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
                  child: AppBackButton(variant: AppIconActionVariant.disc),
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _CityCtaBar(
                  contextLine: contextLine,
                  label: l10n?.homeCityExploreStays ?? 'Explore stays',
                  onPressed: () => context.push(
                    '/hotels',
                    extra: <String, dynamic>{'city': sourceTitle},
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int? _staysCount(HomeItem item) {
    final Object? count = item.metadata['staysCount'];
    if (count is num && count > 0) return count.toInt();
    return null;
  }

  static String? _nonEmpty(String? value) {
    final String trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// The city's story, in the same quiet inner panel the hotel page uses for its
/// key facts. The heading is a section label, not a second title.
class _CityAbout extends StatelessWidget {
  const _CityAbout({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: AppTypography.forLight().titleMedium.copyWith(
            color: context.tokigoColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: TravelCardStyle.innerPanel(context),
          child: Text(
            body,
            style: AppTypography.forLight().body.copyWith(
              color: context.tokigoColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// The hero photo band. With no photo the band becomes a quiet surface with
/// the city glyph — never a fabricated image and never a giant blank block.
class _CityHero extends StatelessWidget {
  const _CityHero({required this.imageUrl, required this.title});

  final String? imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    final String? url = imageUrl;
    if (url == null || url.isEmpty) {
      return ColoredBox(
        color: context.tokigoColors.surfaceSecondary,
        child: Center(
          child: Icon(
            Icons.location_city_rounded,
            size: 48,
            color: context.tokigoColors.textTertiary,
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        CardImage(
          url: url,
          fit: BoxFit.cover,
          fallbackIcon: Icons.photo_camera_outlined,
          semanticLabel: title,
        ),
        // A top wash keeps the floating back control legible; the bottom wash
        // lets the sheet's rounded edge sit on the photo without a hard line.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                context.tokigoColors.scrimSoft,
                Colors.transparent,
                context.tokigoColors.scrimStrong,
              ],
              stops: const <double>[0, 0.4, 1],
            ),
          ),
        ),
      ],
    );
  }
}

/// The pinned dark bar: the city's real region / stay count on the start, the
/// one action on the end. It borrows the hotel details bar's skin so the two
/// expanded surfaces end on the same slab.
class _CityCtaBar extends StatelessWidget {
  const _CityCtaBar({
    required this.contextLine,
    required this.label,
    required this.onPressed,
  });

  final String contextLine;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return StickyCtaBar(
      variant: StickyCtaBarVariant.dark,
      child: Row(
        children: <Widget>[
          if (contextLine.isNotEmpty) ...<Widget>[
            Expanded(
              child: Text(
                contextLine,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: typography.caption.copyWith(
                  color: context.tokigoColors.onCtaBarVariant,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
          ],
          Expanded(
            flex: contextLine.isEmpty ? 1 : 2,
            child: _CityCtaButton(label: label, onPressed: onPressed),
          ),
        ],
      ),
    );
  }
}

/// The white (light) / brand (dark) slab inside the dark bar — the same control
/// the hotel details page pins.
class _CityCtaButton extends StatelessWidget {
  const _CityCtaButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable.wrap(
      child: Material(
        color: context.tokigoColors.ctaBarButton,
        borderRadius: AppRadius.smBorder,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.smBorder,
          child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.forLight().bodyLargeMedium.copyWith(
                color: context.tokigoColors.onCtaBarButton,
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// The attribution a Commons city photo requires.
///
/// The card itself stays image-only; the credit lives on the page that shows
/// the photo at full width. Tapping it opens the file's own Commons page, which
/// is where the full licence text lives — the line only has room for the short
/// name. Without a source URL it is plain text, never a dead link.
class _PhotoCredit extends StatelessWidget {
  const _PhotoCredit({
    required this.credit,
    required this.license,
    required this.source,
  });

  final String credit;
  final String? license;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final String label =
        '${l10n?.homeCityPhotoCredit(credit) ?? 'Photo: $credit'}'
        '${license == null ? '' : ' · $license'}';
    final TextStyle style = AppTypography.forLight().caption.copyWith(
      color: context.tokigoColors.textTertiary,
    );

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
      child: Pressable.wrap(
        enabled: source != null,
        child: InkWell(
          onTap: source == null ? null : () => _openSource(source!),
          borderRadius: AppRadius.smBorder,
          child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  label,
                  style: style,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (source != null) ...<Widget>[
                const SizedBox(width: AppSpacing.xxs),
                Icon(
                  Icons.open_in_new,
                  size: 12,
                  color: context.tokigoColors.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  static Future<void> _openSource(String source) async {
    final Uri? uri = Uri.tryParse(source);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      // A device without a browser cannot open the file page; the credit text
      // is still on screen, so failing silently is the honest behaviour.
    }
  }
}
