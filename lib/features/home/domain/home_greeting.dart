import 'home_composer.dart';

/// Personalized Home greeting (Phase 1B).
///
/// Deterministic ONLY for now: the authenticated variant uses the profile's
/// display name when present and a neutral traveller fallback otherwise — no
/// hardcoded names, and NO AI generation in this phase. The later
/// personalization phases may swap the subtitle via the same contract
/// (e.g. "I found offers for the trip you were looking at"), but the greeting
/// is always rendered SEPARATELY from product cards so the AI can never
/// invent a destination, product, or price inside it.
class HomeGreeting {
  const HomeGreeting({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

/// Builds the greeting for the current composition context.
///
/// - Anonymous (fresh or returning): the standard welcome line, unchanged
///   from Phase 1A so no snapshot/locale behaviour shifts.
/// - Authenticated: `Welcome back, {displayName}` with a safe neutral
///   fallback when the account has no display name. The name is taken ONLY
///   from the composition context — never hardcoded.
/// - Phase 1C: the subtitle becomes CONTEXT-AWARE (deterministic only, no
///   AI): trip context → recent search → viewed → default. When
///   personalization is disabled the neutral line stays.
HomeGreeting buildGreeting(HomeCompositionContext ctx) {
  if (ctx.userState != HomeUserState.authenticated) {
    return const HomeGreeting(
      title: 'Welcome back',
      subtitle: 'Trips and ideas picked for you',
    );
  }
  final name = ctx.displayName?.trim();
  final hasName = name != null && name.isNotEmpty;
  final title = hasName ? 'Welcome back, $name' : 'Welcome back';

  var subtitle = 'Trips and ideas picked for you';
  if (ctx.personalizationEnabled) {
    if (ctx.upcomingDestination != null &&
        ctx.upcomingDestination!.isNotEmpty) {
      subtitle = 'We found options for your trip to ${ctx.upcomingDestination}';
    } else if (ctx.recentSearches.isNotEmpty) {
      subtitle = 'We found options that suit your recent search';
    } else if (ctx.viewedTitles.isNotEmpty) {
      subtitle = 'We found options that suit your trip';
    }
  }
  return HomeGreeting(title: title, subtitle: subtitle);
}
