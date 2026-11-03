import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/features/home/presentation/destination_localization.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/cards/base_card.dart';
import 'package:tokigo/core/widgets/cards/card_image.dart';
import 'package:tokigo/core/widgets/cards/card_scrim_overlay.dart';
import 'package:tokigo/core/widgets/cards/card_skeleton.dart';
import 'package:tokigo/core/widgets/cards/travel_card_style.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// A Discover city in the Home rail.
///
/// Destination discovery is image-led: editorial type sits on a bottom scrim,
/// while hotel facts use a separate, structured surface.
class HomeDiscoveryStayCard extends StatelessWidget {
  const HomeDiscoveryStayCard({
    super.key,
    required this.item,
    required this.onTap,
    this.aspectRatio = 1.3,
    this.fillSheet = true,
  });

  final HomeItem item;
  final VoidCallback? onTap;

  /// Photo width ÷ height. The Home rail passes its own ratio so a city page
  /// and a stay page start and end on the same lines.
  final double aspectRatio;

  /// Fill a bounded rail card; content-sized placements retain the photo ratio.
  final bool fillSheet;

  String? get _region {
    for (final String key in <String>['region', 'country']) {
      final String value = (item.metadata[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  String? _description(BuildContext context) {
    final AppLocalizations? l10n = AppLocalizations.of(context);
    final String languageCode = Localizations.localeOf(context).languageCode;
    final String value = localizedDestinationText(
      item,
      item.description?.trim().isNotEmpty == true
          ? DestinationTextField.description
          : DestinationTextField.subtitle,
      l10n: AppLocalizations.of(context),
      languageCode: languageCode,
    ).trim();
    if (value.isEmpty) return null;
    // The feed's subtitle for a city is often its country, which the region
    // line already states. Repeating it reads as a bug, not as information.
    final String rawRegion = (_region ?? '').trim().toLowerCase();
    final String title = localizedDestinationText(
      item,
      DestinationTextField.title,
      l10n: l10n,
      languageCode: languageCode,
    ).trim().toLowerCase();
    if (rawRegion.isNotEmpty && value.toLowerCase() == rawRegion) return null;
    if (value.toLowerCase() == title) return null;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final String languageCode = Localizations.localeOf(context).languageCode;
    final String? rawRegion = _region;
    final String? region = rawRegion == null
        ? null
        : localizedDestinationText(
            item,
            DestinationTextField.region,
            l10n: l10n,
            languageCode: languageCode,
          );
    final String? description = _description(context);
    final String title = localizedDestinationText(
      item,
      DestinationTextField.title,
      l10n: l10n,
      languageCode: languageCode,
    );
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    return BaseCard(
      onTap: onTap,
      enabled: onTap != null,
      showBorder: true,
      borderColor: TravelCardStyle.borderColor(context),
      showShadow: false,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      margin: EdgeInsets.zero,
      semanticsLabel: title,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded =
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
          final typography = AppTypography.forLight();
          final editorialImage = Stack(
            fit: StackFit.expand,
            children: <Widget>[
              CardImage(
                url: item.imageUrl,
                fit: BoxFit.cover,
                fallbackIcon: Icons.photo_camera_outlined,
                semanticLabel: title,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.transparent,
                      context.tokigoColors.photoScrim.withValues(alpha: 0.24),
                      context.tokigoColors.photoScrim.withValues(alpha: 0.88),
                    ],
                    stops: const <double>[0.3, 0.62, 1],
                  ),
                ),
              ),
              PositionedDirectional(
                start: AppSpacing.lg,
                end: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (region != null) ...<Widget>[
                      Text(
                        isRtl ? region : region.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.captionSemibold.copyWith(
                          color: CardScrimColors.onScrimVariant,
                          letterSpacing: isRtl ? 0 : 0.8,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typography.title.copyWith(
                        color: CardScrimColors.onScrim,
                        fontWeight: FontWeight.w700,
                        height: 1.16,
                      ),
                    ),
                    if (description != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.caption.copyWith(
                          color: CardScrimColors.onScrimVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    TravelActionHint(
                      label: l10n?.navExplore ?? 'Explore',
                      color: CardScrimColors.onScrim,
                    ),
                  ],
                ),
              ),
            ],
          );
          return bounded && fillSheet
              ? SizedBox.expand(child: editorialImage)
              : AspectRatio(aspectRatio: aspectRatio, child: editorialImage);
        },
      ),
    );
  }
}

/// City-card skeleton matching the full-bleed editorial destination layout.
class HomeDiscoveryStayCardSkeleton extends StatelessWidget {
  const HomeDiscoveryStayCardSkeleton({
    super.key,
    this.aspectRatio = 1.3,
    this.semanticsLabel = 'Loading destination',
    this.fillSheet = true,
  });

  final double aspectRatio;
  final String semanticsLabel;
  final bool fillSheet;

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      onTap: null,
      enabled: false,
      loading: true,
      showBorder: true,
      borderColor: TravelCardStyle.borderColor(context),
      showShadow: false,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      margin: EdgeInsets.zero,
      semanticsLabel: semanticsLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded =
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
          final Widget image = Stack(
            fit: StackFit.expand,
            children: <Widget>[
              CardSkeleton.image(),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Colors.transparent, Color(0xCC000000)],
                    stops: <double>[0.25, 1],
                  ),
                ),
              ),
              PositionedDirectional(
                start: AppSpacing.lg,
                end: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CardSkeleton.text(width: 78, height: 12),
                    CardSkeleton.gap(height: AppSpacing.xs),
                    CardSkeleton.title(width: 150, height: 26),
                    CardSkeleton.gap(height: AppSpacing.md),
                    CardSkeleton.text(width: 68, height: 14),
                  ],
                ),
              ),
            ],
          );
          return bounded && fillSheet
              ? SizedBox.expand(child: image)
              : AspectRatio(aspectRatio: aspectRatio, child: image);
        },
      ),
    );
  }
}
