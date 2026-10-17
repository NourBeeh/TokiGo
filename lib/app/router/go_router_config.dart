import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/domain/models/offers/car_offer.dart';
import '../../core/domain/models/offers/flight_offer.dart';
import '../../core/domain/models/offers/hotel_offer.dart';
import '../../core/domain/models/offers/travel_package_offer.dart';
import '../../core/navigation/app_route.dart';
import '../../core/navigation/app_transitions.dart';
import '../../core/theme/app_colors.dart';
import '../../features/bag/presentation/pages/bag_page.dart';
import '../../features/bag/presentation/pages/trip_details_page.dart';
import '../../features/admin/presentation/pages/admin_page.dart';
import '../../features/ai/presentation/pages/ai_chat_page.dart';
import '../../features/ai/presentation/pages/ai_memory_page.dart';
import '../../features/universal_search/presentation/pages/universal_search_page.dart';
import '../../features/booking/presentation/pages/add_ons_page.dart';
import '../../features/booking/presentation/pages/booking_confirmation_page.dart';
import '../../features/booking/presentation/pages/checkout_page.dart';
import '../../features/booking/presentation/pages/passenger_details_page.dart';
import '../../features/groups/presentation/pages/groups_page.dart';
import '../../features/home/presentation/pages/explore_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/auth_page.dart';
import '../../features/profile/presentation/pages/onboarding_page.dart';
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
import '../shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Phase 17 keeps the app open to guests: only the Profile surface branches on
/// auth state. A mandatory login redirect stays available via this flag but is
/// intentionally off — do not lock the whole app behind auth.
const bool _authRedirectEnabled = false;

/// Tab branches of the bottom navigation shell.

final goRouterProvider = Provider<GoRouter>((ref) {
  final authUser = ref.watch(authUserProvider);
  final onboarding = ref.watch(onboardingProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      // First-launch onboarding gate: show the intro exactly once, before
      // any other destination is reachable.
      final isOnboarding = state.matchedLocation == '/onboarding';
      if (onboarding.ready && !onboarding.seen && !isOnboarding) {
        return '/onboarding';
      }
      if (onboarding.seen && isOnboarding) {
        return '/';
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
          return WeTravellersShell(
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
                pageBuilder: (context, state) => fadeThroughPage(
                  name: 'home',
                  child: const HomePage(),
                ),
                routes: <GoRoute>[
                  GoRoute(
                    path: 'flights',
                    name: 'flights',
                    pageBuilder: (context, state) => fadeThroughPage(
                      name: 'flights',
                      child: const FlightSearchPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'hotels',
                    name: 'hotels',
                    pageBuilder: (context, state) => fadeThroughPage(
                      name: 'hotels',
                      child: const HotelSearchPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'cars',
                    name: 'cars',
                    pageBuilder: (context, state) => fadeThroughPage(
                      name: 'cars',
                      child: const CarSearchPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'packages',
                    name: 'packages',
                    pageBuilder: (context, state) => fadeThroughPage(
                      name: 'packages',
                      child: const PackagesSearchPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'offer-details',
                    name: 'offer_details',
                    pageBuilder: (context, state) => fadeThroughPage(
                      name: 'offer_details',
                      child: OfferDetailsPage(
                        offer: state.extra!,
                        hue: hueForOffer(state.extra),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'bag',
                    name: 'bag',
                    pageBuilder: (context, state) => fadeThroughPage(
                      name: 'bag',
                      child: const BagPage(),
                    ),
                    routes: <GoRoute>[
                      GoRoute(
                        path: ':tripId',
                        name: 'trip_details',
                        pageBuilder: (context, state) => fadeThroughPage(
                          name: 'trip_details',
                          child: TripDetailsPage(
                            tripId: state.pathParameters['tripId']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'notifications',
                    name: 'notifications',
                    pageBuilder: (context, state) => fadeThroughPage(
                      name: 'notifications',
                      child: const NotificationsPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'wishlist',
                    name: 'wishlist',
                    pageBuilder: (context, state) => fadeThroughPage(
                      name: 'wishlist',
                      child: const WishlistPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'profile',
                    name: 'profile',
                    pageBuilder: (context, state) => fadeThroughPage(
                      name: 'profile',
                      child: const ProfilePage(),
                    ),
                  ),
                  GoRoute(
                    path: 'settings',
                    name: 'settings',
                    pageBuilder: (context, state) => fadeThroughPage(
                      name: 'settings',
                      child: const SettingsPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'auth',
                    name: 'auth',
                    pageBuilder: (context, state) => fadeThroughPage(
                      name: 'auth',
                      child: const AuthPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'booking/review',
                    name: 'booking_review',
                    pageBuilder: (context, state) => fadeThroughPage(
                      name: 'booking_review',
                      child: const BookingReviewPage(),
                    ),
                    routes: <GoRoute>[
                      GoRoute(
                        path: 'passengers',
                        name: 'booking_passengers',
                        pageBuilder: (context, state) => fadeThroughPage(
                          name: 'booking_passengers',
                          child: const PassengerDetailsPage(),
                        ),
                      ),
                      GoRoute(
                        path: 'add-ons',
                        name: 'booking_add_ons',
                        pageBuilder: (context, state) => fadeThroughPage(
                          name: 'booking_add_ons',
                          child: const AddOnsPage(),
                        ),
                      ),
                      GoRoute(
                        path: 'checkout',
                        name: 'booking_checkout',
                        pageBuilder: (context, state) => fadeThroughPage(
                          name: 'booking_checkout',
                          child: const CheckoutPage(),
                        ),
                      ),
                      GoRoute(
                        path: 'confirmation',
                        name: 'booking_confirmation',
                        pageBuilder: (context, state) => fadeThroughPage(
                          name: 'booking_confirmation',
                          child: const BookingConfirmationPage(),
                        ),
                      ),
                    ],
                  ),
                  // NAV: the former tab pages live on the Home branch as
                  // pushed routes — single-branch, Home-centric navigation.
                  GoRoute(
                    path: 'search',
                    name: 'search',
                    pageBuilder: (context, state) => fadeThroughPage(
                      name: 'search',
                      child: const SearchHubPage(),
                    ),
                    routes: <GoRoute>[
                      GoRoute(
                        path: 'transfers',
                        name: 'transfers',
                        pageBuilder: (context, state) => fadeThroughPage(
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
                    pageBuilder: (context, state) => fadeThroughPage(
                      name: 'groups',
                      child: const GroupsPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'explore',
                    name: 'explore',
                    pageBuilder: (context, state) => fadeThroughPage(
                      name: 'explore',
                      child: const ExplorePage(),
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
        pageBuilder: (context, state) => fadeThroughPage(
          name: 'onboarding',
          child: const OnboardingPage(),
        ),
      ),
      // Full-screen AI chat — deliberately OUTSIDE the shell so the bottom
      // bar does not render on top of it. Fade-through keeps the unified
      // motion language; iOS edge-swipe-back still pops the route.
      // Admin panel — root route outside the shell (ADM-A2).
      GoRoute(
        path: '/admin',
        name: 'admin',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => fadeThroughPage(
          name: 'admin',
          child: const AdminPage(),
        ),
      ),
      GoRoute(
        path: '/ai-chat',
        name: 'ai_chat',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => fadeThroughPage(
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
        pageBuilder: (context, state) => fadeThroughPage(
          name: 'ai_memory',
          child: const AiMemoryPage(),
        ),
      ),
      // Universal Search + AI (US-1) — root route outside the shell so the
      // floating pill never renders over the search experience. Container
      // transform: the Home pill hero-morphs into the page header while
      // this transition supplies the scrim + content reveal.
      GoRoute(
        path: '/smart-search',
        name: 'smart_search',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => containerTransformPage(
          name: 'smart_search',
          child: const UniversalSearchPage(),
        ),
      ),
    ],
  );
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
