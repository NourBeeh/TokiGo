import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';

/// US-5 — the SAFE personalization signals Universal Search may consume.
///
/// Built from the EXISTING R-4 profile read model (`GET /profile/me`:
/// behavioral `derived` + `derivedPreferences`) and the read-only
/// [LocalBehaviorStore] (anonymous local memory). Deliberately closed:
///
/// - NO explicit conversation memories (`preferred_destination` /
///   `preferred_budget`) — the 2C rule forbids them here; that is PH-7's
///   separately-approved surface.
/// - NO tokens, credentials, GPS finer than country, or raw payloads.
///
/// A default-constructed value carries NO signals: every consumer must then
/// behave EXACTLY as before personalization existed.
@immutable
class SearchPersonalizationSignals {
  const SearchPersonalizationSignals({
    this.personalizationEnabled = true,
    this.topDestinations = const [],
    this.favoriteHotels = const [],
    this.viewedTitles = const [],
    this.recentDestinations = const [],
    this.recentSearchLabels = const [],
    this.budgetMax,
  });

  /// No signals at all — the neutral (cold-start / anonymous) value.
  static const SearchPersonalizationSignals none =
      SearchPersonalizationSignals();

  /// The user's opt-out (`personalizationEnabled == false` → never apply).
  final bool personalizationEnabled;

  /// Derived top destinations (behavior/memory spine), highest confidence first.
  final List<String> topDestinations;

  /// Derived favorite hotel titles.
  final List<String> favoriteHotels;

  /// Derived last-viewed hotel title(s).
  final List<String> viewedTitles;

  /// Derived recent destinations, most-recently-touched first.
  final List<String> recentDestinations;

  /// Local recent search labels (anonymous local memory).
  final List<String> recentSearchLabels;

  /// Derived budget ceiling (used only as a weak assist — never a filter).
  final double? budgetMax;

  bool get hasSignals =>
      topDestinations.isNotEmpty ||
      favoriteHotels.isNotEmpty ||
      viewedTitles.isNotEmpty ||
      recentDestinations.isNotEmpty ||
      recentSearchLabels.isNotEmpty ||
      budgetMax != null;

  /// Personalization may only do anything when opted-in AND signals exist.
  bool get isActive => personalizationEnabled && hasSignals;

  /// Serializable, value-free debug view (never logs raw memory payloads).
  Map<String, dynamic> toDebugMap() => <String, dynamic>{
    'personalizationEnabled': personalizationEnabled,
    'topDestinationCount': topDestinations.length,
    'favoriteHotelCount': favoriteHotels.length,
    'viewedTitleCount': viewedTitles.length,
    'recentDestinationCount': recentDestinations.length,
    'recentSearchCount': recentSearchLabels.length,
    'hasBudgetMax': budgetMax != null,
  };
}

/// The outcome of personalizing a result set: the (possibly reordered)
/// sections plus whether the order actually changed. `applied` drives the
/// honest "ordered by your preferences" hint — it is false whenever the
/// engine left the explicit search order untouched.
@immutable
class PersonalizedSections {
  const PersonalizedSections(this.sections, {required this.applied});

  final List<HomeSection> sections;
  final bool applied;

  static PersonalizedSections unchanged(List<HomeSection> sections) =>
      PersonalizedSections(sections, applied: false);
}

/// US-5 — deterministic search personalization.
///
/// Mirrors the EXISTING [RecommendationService] priority vocabulary (the
/// same reason ladder the Home engine already uses) but operates on search
/// result [HomeItem]s. Reuses that architecture without modifying it.
///
/// HARD RULES (spec):
/// - MAY influence ordering + suggestions. NEVER filters and NEVER changes
///   which items were returned, their provider data, or cache/price truth.
/// - Explicit user intent ALWAYS wins: an explicit destination is pinned
///   above every personalized signal (`explicitAnchor`).
/// - Same input → same output (stable tie-break on original position).
/// - Disabled / no signals → the input is returned UNCHANGED.
class SearchPersonalization {
  const SearchPersonalization();

  // -------------------------------------------------------------------------
  // Suggestions: surface personalized destinations first, stable otherwise.
  // -------------------------------------------------------------------------

  List<String> orderSuggestions(
    List<String> suggestions,
    SearchPersonalizationSignals signals,
  ) {
    if (suggestions.length < 2 || !signals.isActive) return suggestions;

    final indexed = suggestions.asMap().entries.toList();
    indexed.sort((a, b) {
      final sa = _suggestionScore(a.value, signals);
      final sb = _suggestionScore(b.value, signals);
      if (sa != sb) return sb.compareTo(sa);
      return a.key.compareTo(b.key); // stable
    });
    return indexed.map((e) => e.value).toList();
  }

  double _suggestionScore(String suggestion, SearchPersonalizationSignals s) {
    final hay = suggestion.toLowerCase();
    var score = 0.0;
    for (final d in s.topDestinations) {
      if (_matches(hay, d)) {
        score += 10;
        break;
      }
    }
    for (final d in s.recentDestinations) {
      if (_matches(hay, d)) {
        score += 6;
        break;
      }
    }
    for (final h in s.favoriteHotels) {
      if (_matches(hay, h)) {
        score += 4;
        break;
      }
    }
    for (final label in s.recentSearchLabels) {
      if (_matches(hay, label)) {
        score += 2;
        break;
      }
    }
    return score;
  }

  // -------------------------------------------------------------------------
  // Results: reorder WITHIN each section (never across sections, never drop).
  // -------------------------------------------------------------------------

  PersonalizedSections orderResults(
    List<HomeSection> sections,
    SearchPersonalizationSignals signals, {
    String? explicitDestination,
  }) {
    if (sections.isEmpty || !signals.isActive) {
      return PersonalizedSections.unchanged(sections);
    }

    var changed = false;
    final out = <HomeSection>[];
    for (final section in sections) {
      if (section.items.length < 2) {
        out.add(section);
        continue;
      }
      final indexed = section.items.asMap().entries.toList();
      indexed.sort((a, b) {
        final sa = _itemScore(a.value, signals, explicitDestination);
        final sb = _itemScore(b.value, signals, explicitDestination);
        if (sa != sb) return sb.compareTo(sa);
        return a.key.compareTo(b.key); // stable
      });
      final reordered = indexed.map((e) => e.value).toList();
      if (!changed && !_sameOrder(section.items, reordered)) changed = true;
      out.add(
        HomeSection(
          id: section.id,
          title: section.title,
          layout: section.layout,
          items: reordered,
        ),
      );
    }
    return PersonalizedSections(out, applied: changed);
  }

  double _itemScore(
    HomeItem item,
    SearchPersonalizationSignals s,
    String? explicitDestination,
  ) {
    final hay = '${item.title} ${item.subtitle ?? ''}'.toLowerCase();
    var score = 0.0;

    // EXPLICIT INTENT ALWAYS WINS — pinned far above every personalized
    // signal so a habitual destination can never outrank the one asked for.
    if (explicitDestination != null &&
        explicitDestination.trim().isNotEmpty &&
        _matches(hay, explicitDestination)) {
      score += 10000;
    }

    for (final f in s.favoriteHotels) {
      if (_matchesAll(hay, f)) {
        score += 300;
        break;
      }
    }
    for (final v in s.viewedTitles) {
      if (_matchesAll(hay, v)) {
        score += 200;
        break;
      }
    }
    for (final d in s.topDestinations) {
      if (_matches(hay, d)) {
        score += 150;
        break;
      }
    }
    for (final d in s.recentDestinations) {
      if (_matches(hay, d)) {
        score += 100;
        break;
      }
    }
    for (final label in s.recentSearchLabels) {
      if (_matches(hay, label)) {
        score += 50;
        break;
      }
    }

    // Budget assist — weak, and ONLY a nudge (never filters items out).
    if (s.budgetMax != null &&
        item.price != null &&
        item.price! <= s.budgetMax!) {
      score += 5;
    }

    // General discovery baseline (quality × popularity) — the existing
    // RecommendationService shape, kept tiny so it never dominates.
    final rating = item.rating ?? 0;
    final reviews = item.reviewCount ?? 0;
    score += rating * (1 + _log10(reviews + 1)) * 0.5;

    return score;
  }

  // -------------------------------------------------------------------------

  bool _sameOrder(List<HomeItem> a, List<HomeItem> b) {
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  double _log10(num x) => x <= 0 ? 0 : math.log(x.toDouble()) / math.ln10;

  static const Set<String> _stopWords = {
    'in',
    'the',
    'a',
    'an',
    'to',
    'of',
    'for',
    'and',
    'at',
    'on',
    'hotels',
    'hotel',
    'flights',
    'flight',
    'cars',
    'car',
  };

  /// Word-overlap match — the SAME semantics as the existing Home
  /// `RecommendationService._looselyMatches` (reused, not reinvented).
  bool _matches(String haystack, String needle) {
    final n = needle.toLowerCase().trim();
    if (n.isEmpty) return false;
    if (haystack.contains(n)) return true;
    final words = n
        .split(RegExp(r'[^a-z0-9\u0600-\u06FF]+'))
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toList();
    if (words.isEmpty) return false;
    return words.any(haystack.contains);
  }

  /// Stricter match for FAVORITE/VIEWED hotel names: every significant word
  /// of the remembered name must appear (or the whole name is contained).
  /// Without this, two hotels in the same city would both "match" a favorite
  /// because they share the city word — a false personalization signal.
  bool _matchesAll(String haystack, String needle) {
    final n = needle.toLowerCase().trim();
    if (n.isEmpty) return false;
    if (haystack.contains(n)) return true;
    final words = n
        .split(RegExp(r'[^a-z0-9\u0600-\u06FF]+'))
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toList();
    if (words.isEmpty) return false;
    return words.every(haystack.contains);
  }
}
