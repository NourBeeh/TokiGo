import 'dart:math' as math;

import 'package:tokigo/features/home/domain/personalization_context.dart';

/// Deterministic recommendation ranking (Phase 1C + 2B derived layer).
///
/// Ranks REAL candidates from the R-4 recommendation flow using fixed signal
/// priorities — NO ML, NO invented data, price is never the sole reason:
///
///   1. explicit user preference (preferredStars/budgetMax from the profile)
///   1c. Phase 2B: derived behavioral preferences (memory spine) — ranked
///       between a single recent search and explicit preferences; absent
///       (guests/older backend) keeps the ranking exactly as Phase 1C.
///   2. recent search (label match against candidate city/title)
///   3. recent view (viewed-title match)
///   4. favorite (favorite-title match)
///   5. trip context (upcoming destination match)
///   6. geo/context (country match)
///   7. general discovery (rating×log(reviews) baseline)
///
/// Same input → same output, always.
class RecommendationService {
  const RecommendationService();

  /// Ranks [candidates] for the given context. Never mutates candidate data;
  /// only reorders + annotates the REASON on each entry.
  List<PersonalizationCandidate> rank(
    List<PersonalizationCandidate> candidates,
    PersonalizationContext ctx,
  ) {
    if (candidates.isEmpty) return candidates;
    if (!ctx.personalizationEnabled) {
      // Opted out: neutral ordering, discovery reason only.
      return candidates
          .map((c) => _withReason(c, 'discovery', 'discovery'))
          .toList();
    }

    final searchLabels =
        ctx.recentSearches.map((s) => s.label.toLowerCase()).toList();
    final viewed = ctx.viewedTitles.map((e) => e.toLowerCase()).toList();
    final favorites = ctx.favoriteTitles.map((e) => e.toLowerCase()).toList();
    final upcoming = ctx.upcomingDestination?.toLowerCase();
    final country = ctx.geoCountryCode?.toUpperCase();
    final preferredStars = _asNum(ctx.profile?.preferences['preferredStars']);
    final budgetMax = _asNum(ctx.profile?.preferences['budgetMax']);
    // Phase 2B — derived behavioral preferences from the memory spine. Null
    // (guests / older backend / derivation failure) keeps the ranking
    // EXACTLY as Phase 1C — the derived layer is strictly additive.
    final derivedTops =
        ctx.derivedPreferences?.topDestinations.map((d) => d.name.toLowerCase()).toList() ??
            const <String>[];
    final derivedBudgetMax = ctx.derivedPreferences?.budgetRange?.max;
    final scored = candidates.map((c) {
      final haystack = '${c.title} ${c.subtitle ?? ''}'.toLowerCase();
      var score = 0.0;
      var reason = 'discovery';
      var source = c.source;

      // 6) Geo/context.
      if (country != null &&
          (haystack.contains(country) ||
              haystack.contains(_countryName(country) ?? ''))) {
        score += 1;
        if (reason == 'discovery') reason = 'geo';
      }

      // 5) Trip context.
      if (upcoming != null && upcoming.isNotEmpty && _looselyMatches(haystack, upcoming)) {
        score += 2;
        reason = 'trip_context';
      }

      // 4) Favorite.
      for (final f in favorites) {
        if (f.isNotEmpty && _looselyMatches(haystack, f)) {
          score += 3;
          reason = 'favorite';
          source = 'profile';
          break;
        }
      }

      // 3) Recent view.
      for (final v in viewed) {
        if (v.isNotEmpty && _looselyMatches(haystack, v)) {
          score += 4;
          reason = 'recent_view';
          source = 'profile';
          break;
        }
      }

      // 2) Recent search — a label like "Hotels in Cairo" matches any
      //    candidate mentioning Cairo (shared significant words).
      for (final label in searchLabels) {
        if (label.isNotEmpty && _looselyMatches(haystack, label)) {
          score += 5;
          reason = 'recent_search';
          source = 'local';
          break;
        }
      }

      // 1c) Phase 2B — derived behavioral preferences (memory spine):
      //     ranked between a single recent search and explicit preferences.
      for (final dest in derivedTops) {
        if (dest.isNotEmpty && _looselyMatches(haystack, dest)) {
          score += 5.5;
          if (reason == 'discovery' || reason == 'geo' || reason == 'trip_context') {
            reason = 'profile_preference';
            source = 'memory';
          }
          break;
        }
      }

      // 1) Explicit preference (strongest).
      if (preferredStars != null && c.rating != null) {
        final alignment = 1 - ((c.rating! - preferredStars).abs() / 5);
        if (alignment > 0.5) {
          score += 6 * alignment;
          if (reason == 'discovery' || reason == 'geo') {
            reason = 'profile_preference';
            source = 'profile';
          }
        }
      }
      if (budgetMax != null && c.price != null && c.price! <= budgetMax) {
        score += 1.5; // Budget fit assists, never dominates.
      }
      // Derived budget assist (2B) — used ONLY when no explicit budgetMax.
      if (budgetMax == null &&
          derivedBudgetMax != null &&
          c.price != null &&
          c.price! <= derivedBudgetMax) {
        score += 1.2; // Assist, never dominates.
      }

      // 7) General discovery baseline: quality × popularity.
      final rating = c.rating ?? 0;
      final reviews = c.reviewCount ?? 0;
      score += rating * (1 + _log10(reviews + 1)) * 0.5;

      return _ScoredEntry(c, score, reason, source);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored
        .map((e) => _withReason(e.candidate, e.reason, e.source))
        .toList();
  }

  double _log10(num x) => x <= 0 ? 0 : math.log(x.toDouble()) / math.ln10;

  /// Word-overlap match: true when [haystack] shares any significant word
  /// with [needle] ("hotels in cairo" ↔ "cairo grand hotel" → true).
  static const Set<String> _stopWords = {
    'in', 'the', 'a', 'an', 'to', 'of', 'for', 'and', 'at', 'on', 'hotels',
    'hotel', 'flights', 'flight', 'cars', 'car',
  };

  bool _looselyMatches(String haystack, String needle) {
    if (haystack.contains(needle)) return true;
    final words = needle
        .split(RegExp(r'[^a-z0-9\u0600-\u06FF]+'))
        .where((w) =>
            w.length > 2 && !_stopWords.contains(w))
        .toList();
    if (words.isEmpty) return false;
    return words.any((w) => haystack.contains(w));
  }

  PersonalizationCandidate _withReason(
    PersonalizationCandidate c,
    String reason,
    String source,
  ) {
    return PersonalizationCandidate(
      id: c.id,
      title: c.title,
      subtitle: c.subtitle,
      imageUrl: c.imageUrl,
      price: c.price,
      currency: c.currency,
      rating: c.rating,
      reviewCount: c.reviewCount,
      reason: reason,
      source: source,
      confidence: c.confidence,
    );
  }

  double? _asNum(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  String? _countryName(String code) {
    const names = <String, String>{
      'EG': 'egypt',
      'AE': 'uae',
      'SA': 'saudi',
      'TR': 'turkey',
      'FR': 'france',
    };
    return names[code];
  }
}

class _ScoredEntry {
  _ScoredEntry(this.candidate, this.score, this.reason, this.source);
  final PersonalizationCandidate candidate;
  final double score;
  final String reason;
  final String source;
}
