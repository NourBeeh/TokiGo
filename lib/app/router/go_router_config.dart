import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_state.dart';
import '../../core/navigation/resume_destination.dart';
import '../../core/storage/resume_destination_store.dart';
import '../../core/domain/models/home/home_item.dart';
import '../../core/domain/models/offers/car_offer.dart';
import '../../core/domain/models/offers/flight_offer.dart';
import '../../core/domain/models/offers/hotel_offer.dart';
import '../../core/domain/models/offers/travel_package_offer.dart';
import '../../core/navigation/app_route.dart';
import '../../core/navigation/app_transitions.dart';
import '../../core/theme/app_colors.dart';
import '../../features/ai/presentation/widgets/swipe_from_right_to_pop.dart';
import '../../features/bag/presentation/pages/bag_page.dart';
import '../../features/bag/presentation/pages/trip_details_page.dart';
import '../../features/admin/presentation/pages/admin_page.dart';
import '../../features/ai/presentation/pages/ai_chat_page.dart';
import '../../features/ai/presentation/pages/ai_memory_page.dart';
import '../../features/booking/presentation/pages/add_ons_page.dart';
import '../../features/booking/presentation/pages/booking_confirmation_page.dart';
import '../../features/booking/presentation/pages/checkout_page.dart';
import '../../features/booking/presentation/pages/passenger_details_page.dart';
import '../../features/groups/presentation/pages/groups_page.dart';
import '../../features/home/presentation/pages/city_page.dart';
import '../../features/home/presentation/pages/explore_cities_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/trip_builder_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/auth_page.dart';
import '../../features/profile/presentation/pages/onboarding_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/profile/presentation/pages/wishlist_page.dart';
import '../../features/search/presentation/pages/booking_review_page.dart';
import '../../features/search/presentation/pages/car_search_page.dart';
import '../../features/search/presentation/pages/flight_search_page.dart';
import '../../features/search/presentation/pages/hotel_search_page.dart';
import '../../features/search/presentation/pages/offer_details_page.dart';
import '../../features/search/presentation/pages/packages_search_page.dart';
import '../../features/search/presentation/pages/search_hub_page.dart';
import '../../shared/widgets/placeholder_page.dart';
import '../../shared/providers/onboarding_provider.dart';
import '../config/app_config.dart';
import '../providers/resume_providers.dart';
import '../shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Phase 17 keeps the app open to guests: only the Profile surface branches on
/// auth state. A mandatory login redirect stays available via this flag but is
/// intentionally off — do not lock the whole app behind auth.
const bool _authRedirectEnabled = false;

/// Debounced write of the resume destination (Task 11).
///
/// A navigation burst (quick-action tap → page → detail) would otherwise write
/// the box several times; one write a second after the last change is enough,
/// and the in-memory state is already current for the button.
Timer? _resumePersistTimer;

void _scheduleResumePersist(String location) {
  _resumePersistTimer?.cancel();
  _resumePersistTimer = Timer(const Duration(seconds: 1), () {
    ResumeDestinationStore.write(location);
  });
}

/// Tab branches of the bottom navigation shell.

final goRouterProvider = Provider<GoRouter>((ref) {
  final authUser = ref.watch(authUserProvider);
  final onboarding = ref.watch(onboardingProvider);
  final savedResume = ref.watch(savedResumeLocationProvider);

  // Home is off: '/' is not a destination any more. The resume target is the
  // saved browse location when it is still valid, else the default.
  final String resumeTarget = initialLocationFor(
    homeEnabled: AppConfig.homeEnabled,
    savedResume: savedResume,
    isAuthenticated: authUser != null,
  );

  final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppConfig.homeEnabled ? '/' : resumeTarget,
    redirect: (context, state) {
      // First-launch onboarding gate: show the intro exactly once, before
      // any other destination is reachable.
      final isOnboarding = state.matchedLocation == '/onboarding';
      if (onboarding.ready && !onboarding.seen && !isOnboarding) {
        return '/onboarding';
      }
      if (onboarding.seen && isOnboarding) {
        // Leaving the intro lands on the resume target when Home is off.
        return AppConfig.homeEnabled ? '/' : resumeTarget;
      }
      if (!AppConfig.homeEnabled && state.matchedLocation == '/') {
        return resumeTarget;
      }
      if (!_authRedirectEnabled) {
        return null;
      }
      final isLoggedIn = authUser != null;
      final isLoginRoute = state.matchedLocation == AppRoute.auth.path;

      if (!isLoggedIn && !isLoginRoute) {
        return AppRoute.auth.path;
      }
      if (isLoggedIn && isLoginRoute) {
        return '/';
      }
      return null;
    },
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return TokiGoShell(
            navigationShell: navigationShell,
            location: state.uri,
          );
        },
        branches: <StatefulShellBranch>[
          // ---- Home tab ----
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                name: 'home',
                pageBuilder: (context, state) => slideFromRightPage(
                  key: state.pageKey,
                  restorationId: state.pageKey.value,
                  name: 'home',
                  child: const HomePage(),
                ),
                routes: <GoRoute>[
                  GoRoute(
                    path: 'flights',
                    name: 'flights',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'flights',
                      child: const SwipeFromRightToPop(
                        child: FlightSearchPage(),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'hotels',
                    name: 'hotels',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'hotels',
                      child: const SwipeFromRightToPop(
                        child: HotelSearchPage(),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'cars',
                    name: 'cars',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'cars',
                      child: const SwipeFromRightToPop(child: CarSearchPage()),
                    ),
                  ),
                  GoRoute(
                    path: 'packages',
                    name: 'packages',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'packages',
                      child: const SwipeFromRightToPop(
                        child: PackagesSearchPage(),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'offer-details',
                    name: 'offer_details',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'offer_details',
                      child: SwipeFromRightToPop(
                        child: OfferDetailsPage(
                          offer: state.extra!,
                          hue: hueForOffer(state.extra),
                        ),
                      ),
                    ),
                  ),
                  // Discover tile → the city's own information page. The
                  // tapped HomeItem rides as `extra`; a missing/typed-wrong
                  // extra renders the page's honest "city not found" state.
                  GoRoute(
                    path: 'city',
                    name: 'city',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'city',
                      child: SwipeFromRightToPop(
                        child: CityPage(
                          city: state.extra is HomeItem
                              ? state.extra as HomeItem
                              : null,
                        ),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'explore',
                    name: 'explore_cities',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'explore_cities',
                      child: const SwipeFromRightToPop(
                        child: ExploreCitiesPage(),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'bag',
                    name: 'bag',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'bag',
                      child: SwipeFromRightToPop(
                        child: BagPage(
                          initialLikes:
                              state.uri.queryParameters['section'] == 'likes',
                        ),
                      ),
                    ),
                    routes: <GoRoute>[
                      GoRoute(
                        path: ':tripId',
                        name: 'trip_details',
                        pageBuilder: (context, state) => slideFromRightPage(
                          key: state.pageKey,
                          restorationId: state.pageKey.value,
                          name: 'trip_details',
                          child: SwipeFromRightToPop(
                            child: TripDetailsPage(
                              tripId: state.pathParameters['tripId']!,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'notifications',
                    name: 'notifications',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'notifications',
                      child: const SwipeFromRightToPop(
                        child: NotificationsPage(),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'wishlist',
                    name: 'wishlist',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'wishlist',
                      child: const SwipeFromRightToPop(child: WishlistPage()),
                    ),
                  ),
                  GoRoute(
                    path: 'profile',
                    name: 'profile',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'profile',
                      child: const SwipeFromRightToPop(child: ProfilePage()),
                    ),
                  ),
                  GoRoute(
                    path: 'edit-profile',
                    name: 'edit_profile',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'edit_profile',
                      child: const SwipeFromRightToPop(
                        child: EditProfilePage(),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'settings',
                    name: 'settings',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'settings',
                      child: const SwipeFromRightToPop(child: SettingsPage()),
                    ),
                  ),
                  GoRoute(
                    path: 'auth',
                    name: 'auth',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'auth',
                      child: const SwipeFromRightToPop(child: AuthPage()),
                    ),
                  ),
                  GoRoute(
                    path: 'booking/review',
                    name: 'booking_review',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'booking_review',
                      child: const SwipeFromRightToPop(
                        child: BookingReviewPage(),
                      ),
                    ),
                    routes: <GoRoute>[
                      GoRoute(
                        path: 'passengers',
                        name: 'booking_passengers',
                        pageBuilder: (context, state) => slideFromRightPage(
                          key: state.pageKey,
                          restorationId: state.pageKey.value,
                          name: 'booking_passengers',
                          child: const SwipeFromRightToPop(
                            child: PassengerDetailsPage(),
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'add-ons',
                        name: 'booking_add_ons',
                        pageBuilder: (context, state) => slideFromRightPage(
                          key: state.pageKey,
                          restorationId: state.pageKey.value,
                          name: 'booking_add_ons',
                          child: const SwipeFromRightToPop(child: AddOnsPage()),
                        ),
                      ),
                      GoRoute(
                        path: 'checkout',
                        name: 'booking_checkout',
                        pageBuilder: (context, state) => slideFromRightPage(
                          key: state.pageKey,
                          restorationId: state.pageKey.value,
                          name: 'booking_checkout',
                          child: const SwipeFromRightToPop(
                            child: CheckoutPage(),
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'confirmation',
                        name: 'booking_confirmation',
                        pageBuilder: (context, state) => slideFromRightPage(
                          key: state.pageKey,
                          restorationId: state.pageKey.value,
                          name: 'booking_confirmation',
                          child: const SwipeFromRightToPop(
                            child: BookingConfirmationPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // NAV: the former tab pages live on the Home branch as
                  // pushed routes — single-branch, Home-centric navigation.
                  GoRoute(
                    path: 'search',
                    name: 'search',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'search',
                      child: const SwipeFromRightToPop(child: SearchHubPage()),
                    ),
                    routes: <GoRoute>[
                      GoRoute(
                        path: 'transfers',
                        name: 'transfers',
                        pageBuilder: (context, state) => slideFromRightPage(
                          key: state.pageKey,
                          restorationId: state.pageKey.value,
                          name: 'transfers',
                          child: const PlaceholderPageScaffold(
                            routeName: 'transfers',
                          ),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'groups',
                    name: 'groups',
                    // TEMPORARY — Groups is parked (owner request). The nav
                    // tile is hidden, and the route itself redirects Home so
                    // a deep link or a stale in-app link cannot open it.
                    redirect: (context, state) =>
                        AppConfig.groupsEnabled ? null : '/',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'groups',
                      child: const SwipeFromRightToPop(child: GroupsPage()),
                    ),
                  ),
                  GoRoute(
                    path: 'trip-builder',
                    name: 'trip_builder',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'trip_builder',
                      child: const SwipeFromRightToPop(
                        child: TripBuilderPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // First-launch onboarding — shown when the Hive flag is unset.
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => slideFromRightPage(
          key: state.pageKey,
          restorationId: state.pageKey.value,
          name: 'onboarding',
          child: const OnboardingPage(),
        ),
      ),
      // Full-screen AI chat — deliberately OUTSIDE the shell so the bottom
      // bar does not render on top of it. The horizontal page transition
      // keeps the unified motion language; visible and system Back controls
      // pop the route.
      // Admin panel — root route outside the shell (ADM-A2).
      GoRoute(
        path: '/admin',
        name: 'admin',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => slideFromRightPage(
          key: state.pageKey,
          restorationId: state.pageKey.value,
          name: 'admin',
          child: const SwipeFromRightToPop(child: AdminPage()),
        ),
      ),
      GoRoute(
        path: '/ai-chat',
        name: 'ai_chat',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => slideFromRightPage(
          key: state.pageKey,
          restorationId: state.pageKey.value,
          name: 'ai_chat',
          child: AiChatPage(initialPrompt: state.extra as String?),
        ),
      ),
      // 2C-C2 — "What I Know About You": explicit memory controls, opened
      // from the AI chat header (root-level like /ai-chat).
      GoRoute(
        path: '/ai-memory',
        name: 'ai_memory',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => slideFromRightPage(
          key: state.pageKey,
          restorationId: state.pageKey.value,
          name: 'ai_memory',
          child: const SwipeFromRightToPop(child: AiMemoryPage()),
        ),
      ),
    ],
  );

  // Track the resume destination + the current location. Only allowlisted
  // browse pages are persisted, and only their allowlisted query parameters
  // survive; the write is debounced so a fast navigation burst lands once.
  router.routerDelegate.addListener(() {
    // Keep the full URI (path + safe query) so the button's selected state and
    // the restored location stay faithful to what was saved.
    final String current = router.state.uri.toString();
    ref.read(currentLocationProvider.notifier).state = current;
    final String location = sanitizeResumeLocation(current);
    if (!AppConfig.homeEnabled && location.isNotEmpty) {
      ref.read(resumeDestinationProvider.notifier).state = location;
      _scheduleResumePersist(location);
    }
  });

  // Signing out must not restore the previous account's last page.
  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    final bool wasSignedIn = previous?.isAuthenticated ?? false;
    if (wasSignedIn && !next.isAuthenticated) {
      ResumeDestinationStore.clear();
    }
  });

  return router;
});

/// Maps an offer instance to its feature hue so every surface that pushes
/// '/offer-details' gets a consistent accent color per vertical.
Color hueForOffer(Object? offer) {
  return switch (offer) {
    FlightOffer() => AppColors.flightHue,
    HotelOffer() => AppColors.hotelHue,
    CarOffer() => AppColors.carHue,
    TravelPackageOffer() => AppColors.packageHue,
    _ => AppColors.brand,
  };
}

class PlaceholderPageScaffold extends StatelessWidget {
  const PlaceholderPageScaffold({super.key, required this.routeName});

  final String routeName;

  @override
  Widget build(BuildContext context) {
    final path = routeName == 'home' ? '/' : '/$routeName';
    final route = AppRoute.values.firstWhere(
      (r) => r.path == path,
      orElse: () => AppRoute.home,
    );
    return PlaceholderPage(route: route);
  }
}
