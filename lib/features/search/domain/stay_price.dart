import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';

/// The honest reading of a hotel rate's money — ONE rule for every surface
/// (result card, details page, price block).
///
/// The provider quotes ONE amount for the whole stay (Nuitee's rate total), and
/// sometimes also states a per-night figure. Everything else on screen is
/// arithmetic we are allowed to do *because* the provider gave us the numbers:
///
/// * [total] — the amount the provider quoted for the stay.
/// * [perNight] — the provider's own per-night figure when it sent one, else
///   `total ÷ nights`. **Null when neither exists** — a night count we do not
///   have is never invented, so a stay total is never labelled "/night".
/// * [nights] — the real nights between the offer's own dates.
/// * [derived] — true when [perNight] is our arithmetic, which tells a caller
///   the total is the number that must stay visible beside it.
class StayPrice {
  const StayPrice({
    required this.total,
    required this.perNight,
    required this.nights,
    required this.derived,
  });

  final double? total;
  final double? perNight;
  final int nights;
  final bool derived;

  static StayPrice of(HotelOffer offer) {
    // Night count from the offer's own dates. Rounded, not truncated: a stay
    // that crosses a DST boundary is 2 days 23 hours long, and `inDays` would
    // call that 2 nights — dividing the total by the wrong number and showing
    // a per-night figure the provider never quoted.
    final int minutes = offer.checkOut
        .difference(offer.checkIn)
        .inMinutes
        .abs();
    final int nights = (minutes / (60 * 24)).round();
    final stated = _positive(offer.metadata['pricePerNight']);
    // The offer's own price IS the rate's stay total (the backend maps the
    // provider's rate total into it) — never a per-night figure.
    final total =
        _positive(offer.metadata['totalPrice']) ??
        (stated == null ? _positive(offer.price) : null);

    if (stated != null) {
      return StayPrice(
        total: total,
        perNight: stated,
        nights: nights,
        derived: false,
      );
    }
    if (total == null || nights <= 0) {
      // Nothing to divide by: show the amount, claim no unit.
      return StayPrice(
        total: total,
        perNight: null,
        nights: nights,
        derived: false,
      );
    }
    return StayPrice(
      total: total,
      perNight: total / nights,
      nights: nights,
      derived: true,
    );
  }

  /// The amount to headline when there is no derivable per-night figure.
  double fallbackAmount(double offerPrice) => perNight ?? total ?? offerPrice;

  static double? _positive(Object? value) =>
      value is num && value > 0 ? value.toDouble() : null;
}
