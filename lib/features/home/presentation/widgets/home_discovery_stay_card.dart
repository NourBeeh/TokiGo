import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/presentation/destination_localization.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/cards/base_card.dart';
import 'package:tokigo/core/widgets/cards/card_image.dart';
import 'package:tokigo/core/widgets/cards/card_scrim_overlay.dart';
import 'package:tokigo/core/widgets/cards/card_skeleton.dart';
import 'package:tokigo/core/widgets/cards/travel_card_style.dart';
import 'package:tokigo/features/home/presentation/home_card_dimensions.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// A Discover city in the Home rail.
///
/// Destination discovery is image-led: editorial type sits on a bottom scrim,
/// while hotel facts use a separate, structured surface.
///
/// ## Loading is a state of THIS widget
///
/// [loading] swaps only the content of the card for shimmer placeholders — the
/// shell, the photo box, the scrim and the copy column are the exact same
/// widgets under the exact same constraints. The placeholder therefore cannot
/// drift from the real card when the design changes.
class HomeDiscoveryStayCard extends StatelessWidget {
  const HomeDiscoveryStayCard({
    super.key,
    required this.item,
    required this.onTap,
    this.aspectRatio = HomeCardDimensions.destinationMediaAspectRatio,
    this.fillSheet = true,
    this.loading = false,
    this.semanticsLabel,
  });

  final HomeItem item;
  final VoidCallback? onTap;

  /// Photo width ÷ height. The Home rail passes its own ratio so a city page
  /// and a stay page start and end on the same lines.
  final double aspectRatio;

  /// Fill a bounded rail card; content-sized placements retain the photo ratio.
  final bool fillSheet;

  /// Skeleton state — same geometry, no data. See the class comment.
  final bool loading;

  /// Accessible label. Defaults to the localized city name, or a neutral
  /// loading announcement while [loading].
  final String? semanticsLabel;

  /// The ratio the Home Discover rail uses, shared by every surface that
  /// presents a destination card.
  static const double defaultAspectRatio =
      HomeCardDimensions.destinationMediaAspectRatio;

  /// Neutral label used when a caller does not supply one.
  static const String defaultLoadingLabel = 'Loading destination';

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
    final String? description = loading ? null : _description(context);
    final String title = loading
        ? ''
        : localizedDestinationText(
            item,
            DestinationTextField.title,
            l10n: l10n,
            languageCode: languageCode,
          );
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    return BaseCard(
      onTap: loading ? null : onTap,
      enabled: !loading && onTap != null,
      loading: loading,
      showBorder: true,
      borderColor: TravelCardStyle.borderColor(context),
      showShadow: false,
      padding: EdgeInsets.zero,
      borderRadius: HomeCardDimensions.borderRadius,
      margin: EdgeInsets.zero,
      semanticsLabel:
          semanticsLabel ?? (loading ? defaultLoadingLabel : title),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded =
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
          final Widget surface = _EditorialSurface(
            loading: loading,
            imageUrl: item.imageUrl,
            semanticLabel: loading ? defaultLoadingLabel : title,
            region: region,
            title: title,
            description: description,
            actionLabel: l10n?.navExplore ?? 'Explore',
            isRtl: isRtl,
          );
          return bounded && fillSheet
              ? SizedBox.expand(child: surface)
              : AspectRatio(aspectRatio: aspectRatio, child: surface);
        },
      ),
    );
  }
}

/// City-card skeleton matching the full-bleed editorial destination layout.
///
/// Retained as a named entry point for callers that want to say "placeholder"
/// explicitly; it renders [HomeDiscoveryStayCard] in its loading state, so the
/// geometry is shared by construction rather than copied.
class HomeDiscoveryStayCardSkeleton extends StatelessWidget {
  const HomeDiscoveryStayCardSkeleton({
    super.key,
    this.aspectRatio = HomeCardDimensions.destinationMediaAspectRatio,
    this.semanticsLabel = HomeDiscoveryStayCard.defaultLoadingLabel,
    this.fillSheet = true,
  });

  final double aspectRatio;
  final String semanticsLabel;
  final bool fillSheet;

  @override
  Widget build(BuildContext context) {
    return HomeDiscoveryStayCard(
      item: const HomeItem(
        id: 'loading-destination',
        type: HomeCardType.destination,
        title: '',
      ),
      onTap: null,
      aspectRatio: aspectRatio,
      fillSheet: fillSheet,
      loading: true,
      semanticsLabel: semanticsLabel,
    );
  }
}

/// The photo-plus-scrim surface shared by the loaded and loading card.
///
/// Every constraint in this widget — the stack fit, the scrim gradient and the
/// positioned copy column's insets — applies to BOTH states. Only the children
/// inside the copy column change.
class _EditorialSurface extends StatelessWidget {
  const _EditorialSurface({
    required this.loading,
    required this.imageUrl,
    required this.semanticLabel,
    required this.region,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.isRtl,
  });

  final bool loading;
  final String? imageUrl;
  final String semanticLabel;
  final String? region;
  final String title;
  final String? description;
  final String actionLabel;
  final bool isRtl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (loading)
          CardSkeleton.image()
        else
          CardImage(
            url: imageUrl,
            fit: BoxFit.cover,
            fallbackIcon: Icons.photo_camera_outlined,
            semanticLabel: semanticLabel,
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: loading
                  ? const <Color>[Colors.transparent, Color(0xCC000000)]
                  : <Color>[
                      Colors.transparent,
                      context.tokigoColors.photoScrim.withValues(alpha: 0.24),
                      context.tokigoColors.photoScrim.withValues(alpha: 0.88),
                    ],
              stops: loading
                  ? const <double>[0.25, 1]
                  : const <double>[0.3, 0.62, 1],
            ),
          ),
        ),
        PositionedDirectional(
          start: AppSpacing.lg,
          end: AppSpacing.lg,
          bottom: AppSpacing.lg,
          child: _EditorialCopy(
            loading: loading,
            region: region,
            title: title,
            description: description,
            actionLabel: actionLabel,
            isRtl: isRtl,
          ),
        ),
      ],
    );
  }
}

/// The bottom copy column of the editorial card.
///
/// This ONE widget draws both the real city facts and their placeholders, so
/// row order, alignment, gaps and the pinned action row can never drift
/// between the two states. Placeholder widths/heights mirror the text style
/// each slot carries when loaded.
class _EditorialCopy extends StatelessWidget {
  const _EditorialCopy({
    required this.loading,
    required this.region,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.isRtl,
  });

  final bool loading;
  final String? region;
  final String title;
  final String? description;
  final String actionLabel;
  final bool isRtl;

  // Placeholder sizes — each mirrors the loaded slot it stands in for:
  // region caption (12), two-line title (26), one-line description (14),
  // one-line action hint (14).
  static const double _regionWidth = 78;
  static const double _regionHeight = 12;
  static const double _titleWidth = 150;
  static const double _titleHeight = 26;
  static const double _descriptionWidth = 68;
  static const double _descriptionHeight = 14;
  static const double _actionWidth = 56;
  static const double _actionHeight = 14;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    // In the loading state every slot is occupied, so the placeholder column
    // reserves exactly the room a fully-populated card uses.
    final bool showRegion = loading || region != null;
    final bool showDescription = loading || description != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showRegion) ...<Widget>[
          if (loading)
            CardSkeleton.text(width: _regionWidth, height: _regionHeight)
          else
            Text(
              isRtl ? region! : region!.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.captionSemibold.copyWith(
                color: CardScrimColors.onScrimVariant,
                letterSpacing: isRtl ? 0 : 0.8,
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (loading)
          CardSkeleton.title(width: _titleWidth, height: _titleHeight)
        else
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
        if (showDescription) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          if (loading)
            CardSkeleton.text(
              width: _descriptionWidth,
              height: _descriptionHeight,
            )
          else
            Text(
              description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.caption.copyWith(
                color: CardScrimColors.onScrimVariant,
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (loading)
          CardSkeleton.text(width: _actionWidth, height: _actionHeight)
        else
          TravelActionHint(
            label: actionLabel,
            color: CardScrimColors.onScrim,
          ),
      ],
    );
  }
}
