import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';




import 'package:tokigo/features/booking/presentation/pages/add_ons_page.dart';
import 'package:tokigo/features/booking/presentation/pages/booking_confirmation_page.dart';
import 'package:tokigo/features/booking/presentation/pages/checkout_page.dart';
import 'package:tokigo/features/booking/presentation/pages/passenger_details_page.dart';
import 'package:tokigo/features/bag/presentation/pages/bag_page.dart';
import 'package:tokigo/features/groups/presentation/pages/groups_page.dart';
import 'package:tokigo/features/home/presentation/pages/explore_page.dart';
import 'package:tokigo/features/home/presentation/pages/home_page.dart';
import 'package:tokigo/features/notifications/presentation/pages/notifications_page.dart';
import 'package:tokigo/features/profile/presentation/pages/wishlist_page.dart';
import 'package:tokigo/features/profile/presentation/pages/settings_page.dart';
import 'package:tokigo/features/search/presentation/pages/search_hub_page.dart';
import 'package:tokigo/features/search/presentation/pages/offer_details_page.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';

/// Smoke + interaction coverage for the new premium surfaces built in the
/// full-UI phase: tabs, funnel, bag, groups and detail pages render without
/// layout errors and expose their primary affordances.
void main() {
  Widget wrap(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('Search hub renders hero + four service tiles', (tester) async {
    await tester.pumpWidget(wrap(const SearchHubPage()));
    await tester.pumpAndSettle();
    // Hero card (moved from Home) with its prompt + quick links.
    expect(find.text('Where to next?'), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    // Quick links + service tiles share labels — the pair of each exists.
    expect(find.text('Flights'), findsNWidgets(2));
    expect(find.text('Hotels'), findsNWidgets(2));
    expect(find.text('Cars'), findsNWidgets(2));
    expect(find.text('Packages'), findsNWidgets(2));
  });

  testWidgets('Home leads with welcome line, no hero card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          offlineCacheProvider.overrideWithValue(MemoryOfflineCache()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: HomePage()),
        ),
      ),
    );
    // The home controller loads asynchronously — let the first frame settle
    // and the skeleton path render before asserting on the merged header.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Where to next?'), findsNothing);
  });

  testWidgets('Explore renders destinations, deals and collections',
      (tester) async {
    await tester.pumpWidget(wrap(const ExplorePage()));
    await tester.pumpAndSettle();
    expect(find.text('Sharm El Sheikh'), findsOneWidget);
    // Scroll to the collections section below the fold.
    await tester.scrollUntilVisible(
      find.text('Weekend escapes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Weekend escapes'), findsOneWidget);
  });

  testWidgets('Groups renders create card and group tiles', (tester) async {
    await tester.pumpWidget(wrap(const GroupsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Create a group trip'), findsOneWidget);
    expect(find.text('Dahab diving week'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('Bag renders empty state before any booking', (tester) async {
    await tester.pumpWidget(wrap(const BagPage()));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.luggage_outlined), findsOneWidget);
  });

  testWidgets('Notifications render the mock feed with read/unread', (tester) async {
    await tester.pumpWidget(wrap(const NotificationsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Booking confirmed'), findsOneWidget);
    expect(find.text('Price drop alert'), findsOneWidget);
  });

  testWidgets('Wishlist renders saved items', (tester) async {
    await tester.pumpWidget(wrap(const WishlistPage()));
    await tester.pumpAndSettle();
    expect(find.text('Nile cruise, 4 nights'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(3));
  });

  testWidgets('Settings renders language + currency pickers', (tester) async {
    await tester.pumpWidget(wrap(const SettingsPage()));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
  });

  testWidgets('Add-ons renders catalog with running total', (tester) async {
    await tester.pumpWidget(wrap(const AddOnsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Extra baggage 20kg'), findsOneWidget);
    expect(find.text('Travel insurance'), findsOneWidget);
  });

  testWidgets('Passenger details renders traveler card + contact', (tester) async {
    await tester.pumpWidget(wrap(const PassengerDetailsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Passenger details 1'), findsOneWidget);
    expect(find.text('Contact information'), findsOneWidget);
  });

  testWidgets('Checkout renders methods, card form and breakdown', (tester) async {
    await tester.pumpWidget(wrap(const CheckoutPage()));
    await tester.pumpAndSettle();
    expect(find.text('Credit / debit card'), findsOneWidget);
    expect(find.text('Digital wallet'), findsOneWidget);
    expect(find.text('Card number'), findsOneWidget);
  });

  testWidgets('Confirmation animates the checkmark and shows reference',
      (tester) async {
    await tester.pumpWidget(wrap(const BookingConfirmationPage()));
    await tester.pump();
    expect(find.text('Booking confirmed'), findsOneWidget);
    expect(find.text('View my trip'), findsOneWidget);
  });

  testWidgets('Offer details renders summary card + book CTA', (tester) async {
    final offer = FlightOffer(
      id: 'f1',
      providerId: 'p1',
      providerName: 'EgyptAir',
      title: 'Cairo to Dubai',
      price: 450,
      currency: 'USD',
      origin: 'CAI',
      destination: 'DXB',
      departureTime: DateTime(2026, 1, 1, 8, 0),
      arrivalTime: DateTime(2026, 1, 1, 11, 30),
      airline: 'EgyptAir',
      flightNumber: '985',
      stops: 0,
    );
    await tester.pumpWidget(wrap(OfferDetailsPage(offer: offer)));
    await tester.pumpAndSettle();
    expect(find.text('Cairo to Dubai'), findsWidgets);
    expect(find.text('CAI → DXB'), findsOneWidget);
    expect(find.text('Book now'), findsOneWidget);
  });
}
