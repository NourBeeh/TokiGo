class SearchFilters {
  final double? priceMin;
  final double? priceMax;
  final int? maxStops;
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
    this.minRating,
    this.minStars,
    this.minSeats,
    this.airlines,
    this.amenities,
    this.transmission,
    this.budgetMax,
    this.budgetCurrency,
  });

  SearchFilters copyWith({
    double? priceMin,
    double? priceMax,
    int? maxStops,
    double? minRating,
    int? minStars,
    int? minSeats,
    List<String>? airlines,
    List<String>? amenities,
    String? transmission,
    double? budgetMax,
    String? budgetCurrency,
  }) {
    return SearchFilters(
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      maxStops: maxStops ?? this.maxStops,
      minRating: minRating ?? this.minRating,
      minStars: minStars ?? this.minStars,
      minSeats: minSeats ?? this.minSeats,
      airlines: airlines ?? this.airlines,
      amenities: amenities ?? this.amenities,
      transmission: transmission ?? this.transmission,
      budgetMax: budgetMax ?? this.budgetMax,
      budgetCurrency: budgetCurrency ?? this.budgetCurrency,
    );
  }

  /// Same filters with [rating] as the minimum rating — or with the rating
  /// constraint removed when [rating] is null. [copyWith] cannot clear a
  /// value (null means "keep"), so quick-filter chips use this instead.
  SearchFilters withMinRating(double? rating) => SearchFilters(
    priceMin: priceMin,
    priceMax: priceMax,
    maxStops: maxStops,
    minRating: rating,
    minStars: minStars,
    minSeats: minSeats,
    airlines: airlines,
    amenities: amenities,
    transmission: transmission,
    budgetMax: budgetMax,
    budgetCurrency: budgetCurrency,
  );

  /// Same filters with [stars] as the minimum hotel star class — or with the
  /// class constraint removed when [stars] is null.
  SearchFilters withMinStars(int? stars) => SearchFilters(
    priceMin: priceMin,
    priceMax: priceMax,
    maxStops: maxStops,
    minRating: minRating,
    minStars: stars,
    minSeats: minSeats,
    airlines: airlines,
    amenities: amenities,
    transmission: transmission,
    budgetMax: budgetMax,
    budgetCurrency: budgetCurrency,
  );

  /// Same filters with the traveller's budget cap removed (the chip was
  /// tapped). [copyWith] cannot clear a value (null means "keep"), so this
  /// is the way out of the budget filter.
  SearchFilters withoutBudget() => SearchFilters(
    priceMin: priceMin,
    priceMax: priceMax,
    maxStops: maxStops,
    minRating: minRating,
    minStars: minStars,
    minSeats: minSeats,
    airlines: airlines,
    amenities: amenities,
    transmission: transmission,
  );

  bool get isEmpty =>
      priceMin == null &&
      priceMax == null &&
      maxStops == null &&
      minRating == null &&
      minStars == null &&
      minSeats == null &&
      (airlines?.isEmpty ?? true) &&
      (amenities?.isEmpty ?? true) &&
      transmission == null &&
      budgetMax == null;
}
