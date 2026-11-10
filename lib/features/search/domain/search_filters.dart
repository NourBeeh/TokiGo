class SearchFilters {
  final double? priceMin;
  final double? priceMax;
  final int? maxStops;

  /// Restrict the flight list to **non-stop** flights only.
  ///
  /// It is a post-filter on the provider-returned list (like every other
  /// filter) and never triggers a new search. It is deliberately separate
  /// from [maxStops]: `maxStops` is the "up to N stops" ladder, while this is
  /// the explicit "no stops at all" switch the flight form used to carry.
  final bool directOnly;

  final double? minRating;

  /// Minimum hotel **star class** (1-5, the provider's own classification) —
  /// distinct from [minRating], which is the guest review score.
  final int? minStars;
  final int? minSeats;
  final List<String>? airlines;
  final List<String>? amenities;
  final String? transmission;

  /// Phase 4C — the traveller's own budget cap (from the explicit AI memory).
  ///
  /// It is SEPARATE from [priceMax] (the generic price filter) because it is
  /// only comparable inside ONE currency: the app never converts a price, so
  /// the cap applies to the offers priced in [budgetCurrency] only.
  final double? budgetMax;
  final String? budgetCurrency;

  const SearchFilters({
    this.priceMin,
    this.priceMax,
    this.maxStops,
    this.directOnly = false,
    this.minRating,
    this.minStars,
    this.minSeats,
    this.airlines,
    this.amenities,
    this.transmission,
    this.budgetMax,
    this.budgetCurrency,
  });

  /// Sentinel that distinguishes an omitted argument ("keep the current
  /// value") from an explicit `null` ("clear this value").
  static const Object _unset = Object();

  SearchFilters copyWith({
    Object? priceMin = _unset,
    Object? priceMax = _unset,
    Object? maxStops = _unset,
    Object? directOnly = _unset,
    Object? minRating = _unset,
    Object? minStars = _unset,
    Object? minSeats = _unset,
    Object? airlines = _unset,
    Object? amenities = _unset,
    Object? transmission = _unset,
    Object? budgetMax = _unset,
    Object? budgetCurrency = _unset,
  }) {
    return SearchFilters(
      priceMin: identical(priceMin, _unset)
          ? this.priceMin
          : (priceMin as num?)?.toDouble(),
      priceMax: identical(priceMax, _unset)
          ? this.priceMax
          : (priceMax as num?)?.toDouble(),
      maxStops: identical(maxStops, _unset) ? this.maxStops : maxStops as int?,
      directOnly: identical(directOnly, _unset)
          ? this.directOnly
          : directOnly as bool,
      minRating: identical(minRating, _unset)
          ? this.minRating
          : (minRating as num?)?.toDouble(),
      minStars: identical(minStars, _unset) ? this.minStars : minStars as int?,
      minSeats: identical(minSeats, _unset) ? this.minSeats : minSeats as int?,
      airlines: identical(airlines, _unset)
          ? this.airlines
          : airlines as List<String>?,
      amenities: identical(amenities, _unset)
          ? this.amenities
          : amenities as List<String>?,
      transmission: identical(transmission, _unset)
          ? this.transmission
          : transmission as String?,
      budgetMax: identical(budgetMax, _unset)
          ? this.budgetMax
          : (budgetMax as num?)?.toDouble(),
      budgetCurrency: identical(budgetCurrency, _unset)
          ? this.budgetCurrency
          : budgetCurrency as String?,
    );
  }

  /// Same filters with [rating] as the minimum rating — or with the rating
  /// constraint removed when [rating] is null.
  SearchFilters withMinRating(double? rating) => copyWith(minRating: rating);

  /// Same filters with [stars] as the minimum hotel star class — or with the
  /// class constraint removed when [stars] is null.
  SearchFilters withMinStars(int? stars) => copyWith(minStars: stars);

  /// Same filters with the traveller's budget cap removed (the chip was
  /// tapped).
  SearchFilters withoutBudget() =>
      copyWith(budgetMax: null, budgetCurrency: null);

  bool get isEmpty =>
      priceMin == null &&
      priceMax == null &&
      maxStops == null &&
      !directOnly &&
      minRating == null &&
      minStars == null &&
      minSeats == null &&
      (airlines?.isEmpty ?? true) &&
      (amenities?.isEmpty ?? true) &&
      transmission == null &&
      budgetMax == null;
}
