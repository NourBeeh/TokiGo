enum SortOption {
  recommended,
  priceLowHigh,
  priceHighLow,
  rating,
  duration,
  stops,
}

extension SortOptionExt on SortOption {
  String get label {
    switch (this) {
      case SortOption.recommended:
        return 'Recommended';
      case SortOption.priceLowHigh:
        return 'Price: Low to High';
      case SortOption.priceHighLow:
        return 'Price: High to Low';
      case SortOption.rating:
        return 'Rating';
      case SortOption.duration:
        return 'Duration';
      case SortOption.stops:
        return 'Stops';
    }
  }
}
