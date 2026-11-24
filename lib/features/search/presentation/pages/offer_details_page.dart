import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/offers/base_offer.dart';
import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/domain/models/offers/travel_package_offer.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/localized_date.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/app_back_button.dart';
import 'package:tokigo/core/widgets/app_icon_action.dart';
import 'package:tokigo/core/widgets/cards/card.dart';
import 'package:tokigo/features/home/application/trip_draft_provider.dart';
import 'package:tokigo/features/home/providers/home_providers.dart'
    show eventsTrackerProvider;
import 'package:tokigo/features/profile/application/wishlist_controller.dart';
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';
import 'package:tokigo/features/search/domain/stay_price.dart';
import 'package:tokigo/features/search/presentation/widgets/offer_details/offer_details_content_sections.dart';
import 'package:tokigo/features/search/presentation/widgets/offer_details/offer_details_cta_bar.dart';
import 'package:tokigo/features/search/presentation/widgets/offer_details/offer_details_flight_fare_selector.dart';
import 'package:tokigo/features/search/presentation/widgets/offer_details/offer_details_flight_journey.dart';
import 'package:tokigo/features/search/presentation/widgets/offer_details/offer_details_hero_band.dart';
import 'package:tokigo/features/search/presentation/widgets/offer_details/offer_details_hotel_identity.dart';
import 'package:tokigo/features/search/presentation/widgets/offer_details/offer_details_price_card.dart';
import 'package:tokigo/features/search/presentation/widgets/offer_details/offer_details_room_selector.dart';
import 'package:tokigo/features/search/presentation/widgets/offer_details/offer_details_stay_heart.dart';
import 'package:tokigo/features/search/presentation/widgets/offer_details/offer_details_summary.dart';
import 'package:tokigo/features/search/presentation/widgets/offer_details/offer_details_summary_card.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Unified offer-details page.
///
/// One premium layout for every vertical: a hero band (the provider's photo
/// when there is one, our brand composition when there is not), the offer's own
/// facts, and a sticky price + book CTA bar.
///
/// **Honesty rules (owner, 2026-10-19):**
/// * A flight has no photograph and no aircraft/airline-logo URL, so its band is
///   a brand composition carrying the airline the provider named — never a
///   stand-in picture.
/// * Only fields the provider actually sent are rendered. A missing cabin is not
///   "Economy", a missing rating is not "–", and the price is the provider's
///   total — we never split it into invented base fare / taxes lines.
/// * Every label, date and unit is localized.
///
/// **Structure (Stage 3 refactor, 2026-10-25):** this file owns composition and
/// navigation only. The band, identity block, journey card, summary, price,
/// long-form sections, wishlist heart and CTA bar each live in their own widget
/// under `widgets/offer_details/`, so a change to one block can no longer move
/// the other seven. Behaviour, copy, spacing and semantics are unchanged.
class OfferDetailsPage extends ConsumerStatefulWidget {
  const OfferDetailsPage({super.key, required this.offer, this.hue});

  final Object offer;

  /// Brand composition behind a flight's identity. Null resolves to the active
  /// theme's brand ink, so the band and its on-brand label stay paired in dark
  /// mode instead of painting near-black-on-black.
  final Color? hue;

  @override
  ConsumerState<OfferDetailsPage> createState() => _OfferDetailsPageState();
}

class _OfferDetailsPageState extends ConsumerState<OfferDetailsPage> {
  /// The room-type offer currently chosen on the details page. The page opens
  /// on the hotel's best qualifying offer (the grouped row's own fields), and
  /// the selector swaps it for another valid offer the provider returned.
  HotelOffer? _selectedHotelOffer;

  /// The fare currently chosen for a flight itinerary. The page opens on the
  /// row's cheapest qualifying fare; the selector swaps it for another valid
  /// fare of the SAME itinerary. The exact offer id/provider travels to the
  /// booking hand-off unchanged.
  FlightOffer? _selectedFlightOffer;

  @override
  void initState() {
    super.initState();
    final Object offer = widget.offer;
    _selectedHotelOffer = offer is HotelOffer ? offer : null;
    _selectedFlightOffer = offer is FlightOffer ? offer : null;
  }

  @override
  void didUpdateWidget(OfferDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different offer on the same route (deep-link replacement) must not
    // keep the previous hotel's room or flight's fare selection.
    if (!identical(oldWidget.offer, widget.offer)) {
      final Object offer = widget.offer;
      _selectedHotelOffer = offer is HotelOffer ? offer : null;
      _selectedFlightOffer = offer is FlightOffer ? offer : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).brightness == Brightness.dark
        ? AppTypography.forDark()
        : AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final Color bandHue = widget.hue ?? context.tokigoColors.brand;
    final Object offer = widget.offer;
    final summary = offerDetailsSummaryOf(offer);
    final title = summary.title;
    final subtitle = summary.subtitle;
    final imageUrl = summary.imageUrl;
    final flight = offer is FlightOffer ? offer : null;
    final hotel = offer is HotelOffer ? offer : null;
    // The row's own fields are the cheapest qualifying offer; a room chosen in
    // the selector replaces the displayed price and the booking hand-off.
    final HotelOffer? selectedHotel = hotel == null
        ? null
        : (_selectedHotelOffer ?? hotel);
    // The row's own fields are the cheapest qualifying fare; a fare chosen in
    // the selector replaces the displayed price and the booking hand-off.
    final FlightOffer? selectedFlight = flight == null
        ? null
        : (_selectedFlightOffer ?? flight);
    final price =
        selectedHotel?.price ?? selectedFlight?.price ?? summary.price;
    final currency =
        selectedHotel?.currency ?? selectedFlight?.currency ?? summary.currency;
    final List<HotelOffer> wishlist = ref.watch(wishlistProvider);
    final planningTrip = ref.watch(tripDraftProvider) != null;

    // The pinned bar is a StickyCtaBar slab: md top padding, the 48pt CTA
    // target, md bottom padding (the documented 72pt slab) plus the view
    // inset — the same formula sticky_cta_bar uses, so the last section
    // always clears the bar.
    final double ctaBarClearance =
        MediaQuery.viewPaddingOf(context).bottom +
        AppSpacing.md +
        AppSpacing.minimumTapTarget +
        AppSpacing.md;

    // Phase 1C — behavioral signal: opening a HOTEL offer details page is a
    // `hotel_view` (fire-and-forget; guests/silence handled in the tracker).
    if (hotel != null) {
      ref
          .read(eventsTrackerProvider)
          .hotelView(hotelId: hotel.id, title: title);
    }

    return Scaffold(
      backgroundColor: context.tokigoColors.background,
      body: AiEntranceAnimation(
        child: Stack(
          children: <Widget>[
            CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: AppHeroSheet(
                    // Card G (doc 15 §8): hero 52% (44% under 480pt) and a
                    // sheet biting 24px up into it.
                    media: OfferDetailsHeroBand(
                      imageUrl: imageUrl,
                      hue: bandHue,
                      flight: selectedFlight ?? flight,
                      glyph: _verticalGlyph(offer),
                    ),
                    // The heart over the photo — the wishlist's source (the
                    // owner, 2026-10-20). It only exists for a stay, because
                    // the wishlist holds stays.
                    overlay: hotel != null
                        ? OfferDetailsStayHeart(
                            saved: wishlist.any(
                              (HotelOffer item) => item.id == hotel.id,
                            ),
                            onChanged: (bool value) => ref
                                .read(wishlistProvider.notifier)
                                .setSaved(hotel, value),
                          )
                        : null,
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
                            style: typography.headline.copyWith(
                              color: context.tokigoColors.textPrimary,
                            ),
                          ),
                          // The backend titles a flight "CAI → DXB" and its
                          // subtitle is the same route: say it once. A hotel's
                          // location rides its own identity line (class · place)
                          // instead.
                          if (hotel == null &&
                              subtitle.isNotEmpty &&
                              subtitle != title) ...<Widget>[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              subtitle,
                              style: typography.body.copyWith(
                                color: context.tokigoColors.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          // Reference screen 6's identity block: the hotel's own
                          // class and place, its guest score, and the facilities
                          // it listed — each only when the provider sent it.
                          if (hotel != null) ...<Widget>[
                            OfferDetailsHotelIdentity(hotel: hotel),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          if (flight != null && selectedFlight != null)
                            OfferDetailsFlightJourney(flight: selectedFlight)
                          else
                            OfferDetailsSummaryCard(
                              offer: selectedHotel ?? offer,
                            ),
                          if (hotel != null &&
                              selectedHotel != null) ...<Widget>[
                            const SizedBox(height: AppSpacing.lg),
                            OfferDetailsRoomSelector(
                              offers: hotel.selectableOffers,
                              selected: selectedHotel,
                              onSelected: (HotelOffer value) =>
                                  setState(() => _selectedHotelOffer = value),
                            ),
                          ],
                          if (flight != null &&
                              selectedFlight != null &&
                              flight.selectableOffers.length > 1) ...<Widget>[
                            const SizedBox(height: AppSpacing.lg),
                            OfferDetailsFlightFareSelector(
                              offers: flight.selectableOffers,
                              selected: selectedFlight,
                              onSelected: (FlightOffer value) =>
                                  setState(() => _selectedFlightOffer = value),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          OfferDetailsPriceCard(
                            price: price,
                            currency: currency,
                            stay: selectedHotel != null
                                ? StayPrice.of(selectedHotel)
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          OfferDetailsContentSections(
                            offer: selectedHotel ?? selectedFlight ?? offer,
                          ),
                          SizedBox(height: ctaBarClearance),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // The page's own back control stays visible at every scroll offset
            // (a pushed page always offers a visible back button). It sits on
            // the START edge so Arabic mirrors it to the right — opposite the
            // hero heart, never on top of it.
            Align(
              alignment: AlignmentDirectional.topStart,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.md,
                    top: AppSpacing.xs,
                  ),
                  child: AppBackButton(variant: AppIconActionVariant.plain),
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: OfferDetailsCtaBar(
                  price: price,
                  currency: currency,
                  contextLine: _ctaContext(
                    context,
                    l10n,
                    selectedHotel ?? selectedFlight ?? offer,
                  ),
                  label: price > 0
                      ? planningTrip
                            ? l10n.tripBuilderAddToTrip
                            : l10n.bookNow
                      : l10n.offerCheckAvailability,
                  onPressed: () {
                    final Object bookingTarget =
                        selectedHotel ?? selectedFlight ?? offer;
                    if (planningTrip && bookingTarget is BaseOffer) {
                      ref.read(tripDraftProvider.notifier).add(bookingTarget);
                      context.go('/trip-builder');
                      return;
                    }
                    ref.read(selectedOfferProvider.notifier).state =
                        _selectedOfferFrom(bookingTarget);
                    if (bookingTarget is HotelOffer) {
                      context.push('/booking/hotel-guests');
                    } else {
                      context.push('/booking/review');
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Doc 18 §2.6 — the dark bar's first line is a REAL value: a hotel's own
  /// stay dates and night count, a flight's route, a car's class, a package's
  /// destination. Never a filler, and never a line the sheet already shows
  /// under the title: the bar carries the offer's own timing instead.
  String _ctaContext(
    BuildContext context,
    AppLocalizations l10n,
    Object offer,
  ) {
    return switch (offer) {
      // Missing dates stay missing: no invented day and no invented night
      // count. The bar simply carries the facts the provider sent.
      HotelOffer o => <String>[
        if (o.checkIn != null && o.checkOut != null)
          '${localizedShortDate(context, o.checkIn!)}'
              ' \u2013 ${localizedShortDate(context, o.checkOut!)}',
        if (StayPrice.of(o).nights > 0)
          l10n.hotelNightsCount(StayPrice.of(o).nights),
      ].join(' \u00b7 '),
      FlightOffer o => <String>[
        if (o.flightNumber.isNotEmpty) o.flightNumber,
        localizedShortDate(context, o.departureTime),
      ].join(' \u00b7 '),
      CarOffer o =>
        '${localizedShortDate(context, o.pickupTime)}'
            ' \u2013 ${localizedShortDate(context, o.dropoffTime)}',
      TravelPackageOffer o => l10n.offerDays(o.durationDays),
      _ => '',
    };
  }

  IconData _verticalGlyph(Object offer) {
    return switch (offer) {
      FlightOffer _ => Icons.flight_takeoff_rounded,
      HotelOffer _ => Icons.house_rounded,
      CarOffer _ => Icons.directions_car_rounded,
      TravelPackageOffer _ => Icons.card_travel_rounded,
      _ => Icons.travel_explore_rounded,
    };
  }

  SelectedOffer _selectedOfferFrom(Object offer) {
    // ONE hand-off mapping (`SelectedOffer.fromOffer`) so the confirmation page
    // can name the item that was really booked — title, photo and its own dates.
    if (offer is BaseOffer) return SelectedOffer.fromOffer(offer);
    return const SelectedOffer(
      offerId: '',
      providerId: '',
      providerName: '',
      price: 0,
      currency: 'USD',
      searchId: '',
      offerType: 'flight',
    );
  }
}
