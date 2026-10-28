import 'package:tokigo/l10n/app_localizations.dart';

/// Resolves the Home feed's section titles in the active language.
///
/// The **composer** (the domain layer) builds the section titles as English
/// strings — it is the data layer and it has no access to the localizations.
/// So it also carries a **key** beside the English fallback, and the
/// presentation layer resolves that key here. Without this, an Arabic Home
/// showed English section headings.
///
/// A key with no translation (a section authored in the admin CMS) falls back
/// to the title the backend sent — that content is the publisher's, not the
/// app's.
class HomeSectionTitles {
  const HomeSectionTitles._();

  /// The app's own published sections, by their published title.
  ///
  /// A section's title lives in the database (one column, no per-locale
  /// variants), so the two sections TokiGo itself publishes are resolved here
  /// into the active language. A title the owner wrote in the admin is left
  /// exactly as published — the publisher's words are not the app's to
  /// translate.
  static const Map<String, String> _publishedTitles = <String, String>{
    'Hotels recommended for you': 'homeStaysTitle',
    'Discover': 'discoverTitle',
  };

  /// The section's title, in the active language.
  static String title(
    AppLocalizations? l10n,
    Map<String, dynamic> metadata,
    String fallback,
  ) {
    final String key = metadata['titleKey'] as String? ?? '';
    final String? arg = metadata['titleArg'] as String?;
    if (key.isEmpty) {
      // A published section: the app's own two are resolved into the active
      // language, anything the owner wrote stays as published.
      if (l10n == null) return fallback;
      final String? published = _publishedTitles[fallback];
      if (published == 'homeStaysTitle') return l10n.homeStaysTitle;
      if (published == 'discoverTitle') return l10n.discoverTitle;
      return fallback;
    }
    if (l10n == null) return fallback;
    return switch (key) {
      'completeYourTrip' => l10n.homeCompleteYourTrip,
      'becauseYouViewed' =>
        arg == null || arg.isEmpty
            ? l10n.homeBecauseYouViewedThis
            : l10n.homeBecauseYouViewed(arg),
      'pickedForYou' => l10n.homePickedForYou,
      'basedOnRecentActivity' => l10n.homeBasedOnRecentSearches,
      'basedOnWhatYouViewed' => l10n.homeBasedOnWhatYouViewed,
      _ => fallback,
    };
  }

  /// The section's subtitle, in the active language.
  static String subtitle(
    AppLocalizations? l10n,
    Map<String, dynamic> metadata,
    String fallback,
  ) {
    final String key = metadata['subtitleKey'] as String? ?? '';
    final String? destination = metadata['destination'] as String?;
    if (key.isEmpty || l10n == null) return fallback;
    return switch (key) {
      'finishWhatYouStarted' => l10n.homeFinishWhatYouStarted,
      'forYourTripTo' =>
        destination == null || destination.isEmpty
            ? l10n.homeFinishWhatYouStarted
            : l10n.homeForYourTripTo(destination),
      'picksRelatedToWhatYouSaw' => l10n.homePicksRelatedToWhatYouSaw,
      'basedOnYourProfile' => l10n.homeBasedOnYourProfile,
      'basedOnRecentSearches' => l10n.homeBasedOnRecentSearches,
      'basedOnWhatYouViewed' => l10n.homeBasedOnWhatYouViewed,
      'yourFavoritesFirst' => l10n.homeYourFavoritesFirst,
      'matchedToYourPreferences' => l10n.homeMatchedToYourPreferences,
      'forYourUpcomingTrip' => l10n.homeForYourUpcomingTrip,
      'popularNearYou' => l10n.homePopularNearYou,
      _ => fallback,
    };
  }
}
