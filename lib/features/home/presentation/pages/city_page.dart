import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/widgets/cards/card_image.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The information page a Discover city tile opens.
///
/// It is deliberately a CITY page, not a pre-filtered search: the traveller
/// tapped a place, so the surface explains the place and hands off to its
/// stays. Everything it shows comes from the tapped [HomeItem] — the photo,
/// the name, the region and the description the provider actually sent. When a
/// fact is missing the page omits it rather than inventing it (no fake
/// overview, no fake stay count).
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
        backgroundColor: AppColors.background,
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

    final String title = item.title.trim();
    final String region = _regionOf(item);
    final String? description = _nonEmpty(item.description);
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
    final typography = AppTypography.forLight();
    final double bottom = AppSpacing.xxl + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        // `bottom: false` left the feed's last card under the Android
        // navigation bar (the pill it was written for is gone).
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: AppPageHeader(
                title: title,
                subtitle: region.isEmpty ? null : region,
              ),
            ),
            if (imageUrl != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: AppRadius.lgBorder,
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: CardImage(
                            url: imageUrl,
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.photo_camera_outlined,
                            semanticLabel: title,
                          ),
                        ),
                      ),
                      if (photoCredit != null)
                        _PhotoCredit(
                          credit: photoCredit,
                          license: photoLicense,
                          source: photoSource,
                        ),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n?.homeCityAbout ?? 'About the city',
                      style: typography.titleMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      description ??
                          (l10n?.homeCityOverviewFallback(title) ??
                              'Find your stay in $title and explore '
                                  'everything the city has to offer.'),
                      style: typography.body.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    if (staysCount != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n?.cityStaysCount(staysCount) ??
                            (staysCount == 1 ? '1 stay' : '$staysCount stays'),
                        style: typography.captionSemibold.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  0,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: AppSpacing.minimumTapTarget,
                  child: FilledButton(
                    onPressed: () => context.push(
                      '/hotels',
                      extra: <String, dynamic>{'city': title},
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: AppColors.onBrand,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.mdBorder,
                      ),
                    ),
                    child: Text(
                      l10n?.homeCityExploreStays ?? 'Explore stays',
                      style: typography.bodyLargeMedium.copyWith(
                        color: AppColors.onBrand,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: bottom)),
          ],
        ),
      ),
    );
  }

  /// The region line under the name: provider region, else country, never a
  /// synthesized "Region, Country" string out of nothing.
  static String _regionOf(HomeItem item) {
    final String region = (item.metadata['region'] ?? '').toString().trim();
    if (region.isNotEmpty) return region;
    return (item.metadata['country'] ?? '').toString().trim();
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
      color: AppColors.textTertiary,
    );

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
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
                  color: AppColors.textTertiary,
                ),
              ],
            ],
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
