import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/notifications/domain/app_notification.dart';
import 'package:tokigo/features/notifications/presentation/pages/notifications_page.dart';
import 'package:tokigo/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:tokigo/features/notifications/providers/notifications_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

const Color _normalInk = Color(0xFF1A1A1A);

AppNotification _notification(String id, {bool unread = true, DateTime? at}) {
  return AppNotification(
    id: id,
    title: 'Booking $id',
    body: 'Your trip update $id',
    timestamp: at ?? DateTime(2026, 11, 5, 9, 30),
    unread: unread,
  );
}

Widget _app({
  List<AppNotification> initial = const <AppNotification>[],
  bool disableAnimations = false,
  Locale locale = const Locale('en'),
  VoidCallback? onTap,
}) {
  return ProviderScope(
    overrides: <Override>[
      notificationsProvider.overrideWith(
        (ref) => <AppNotification>[...initial],
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (BuildContext context) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: Scaffold(
              body: Center(
                child: AnimatedNotificationBell(
                  normalColor: _normalInk,
                  onTap: onTap ?? () {},
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

ProviderContainer _container(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(AnimatedNotificationBell)),
    listen: false,
  );
}

void _setFeed(WidgetTester tester, List<AppNotification> feed) {
  _container(tester).read(notificationsProvider.notifier).state = feed;
}

double _flashOpacity(WidgetTester tester) {
  return tester
      .widget<Opacity>(
        find.byKey(const ValueKey<String>('notification-bell-flash')),
      )
      .opacity;
}

Color? _bellColour(WidgetTester tester) {
  return tester
      .widget<Icon>(find.byIcon(Icons.notifications_none_rounded))
      .color;
}

void main() {
  testWidgets('opening with existing notifications does not animate', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(initial: <AppNotification>[_notification('existing')]),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(_flashOpacity(tester), 0);
    expect(_bellColour(tester), _normalInk);
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('home-notification-bell')),
      ),
      const Size(42, 42),
    );
  });

  testWidgets('a new notification shakes once, flashes red and resets', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final Size initialSize = tester.getSize(
      find.byKey(const ValueKey<String>('home-notification-bell')),
    );
    expect(_flashOpacity(tester), 0);

    _setFeed(tester, <AppNotification>[_notification('new-1')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // Mid-animation: the flash is visible, the outline has shifted away from
    // its resting ink, and the button footprint is untouched.
    expect(_flashOpacity(tester), greaterThan(0));
    expect(_bellColour(tester), isNot(_normalInk));
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('home-notification-bell')),
      ),
      initialSize,
    );

    // The flash occupies the exact same 25dp box as the outline bell — it is
    // clipped by the glyph's own silhouette, never a background disc.
    expect(
      tester.getRect(find.byIcon(Icons.notifications_rounded)),
      tester.getRect(find.byIcon(Icons.notifications_none_rounded)),
    );
    expect(
      find.descendant(
        of: find.byType(AnimatedNotificationBell),
        matching: find.byType(ClipOval),
      ),
      findsNothing,
    );

    await tester.pumpAndSettle();
    expect(_flashOpacity(tester), 0);
    expect(_bellColour(tester), _normalInk);
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('home-notification-bell')),
      ),
      initialSize,
    );
  });

  testWidgets('rebuilds and unchanged refreshes never retrigger', (
    tester,
  ) async {
    final AppNotification first = _notification('a');
    await tester.pumpWidget(_app(initial: <AppNotification>[first]));
    await tester.pumpAndSettle();

    // Same id, new list instance and a read-state change: a refresh, not news.
    _setFeed(tester, <AppNotification>[_notification('a', unread: false)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(_flashOpacity(tester), 0);

    // A burst of genuinely new ids produces one animation.
    _setFeed(tester, <AppNotification>[
      _notification('a', unread: false),
      _notification('b'),
      _notification('c'),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_flashOpacity(tester), greaterThan(0));

    // Slip a fourth arrival in mid-flight: the controller must not restart.
    await tester.pump(const Duration(milliseconds: 200));
    final double before = _flashOpacity(tester);
    _setFeed(tester, <AppNotification>[
      _notification('a', unread: false),
      _notification('b'),
      _notification('c'),
      _notification('d'),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_flashOpacity(tester), lessThan(before));

    await tester.pumpAndSettle();
    expect(_flashOpacity(tester), 0);
  });

  testWidgets('the unread badge follows the feed without resizing the bell', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        initial: <AppNotification>[
          _notification('a'),
          _notification('b'),
          _notification('c', unread: false),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final Finder badge = find.byKey(
      const ValueKey<String>('home-notification-badge'),
    );
    expect(badge, findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('home-notification-bell')),
      ),
      const Size(42, 42),
    );

    _setFeed(tester, <AppNotification>[
      _notification('a', unread: false),
      _notification('b', unread: false),
      _notification('c', unread: false),
    ]);
    await tester.pumpAndSettle();
    expect(badge, findsNothing);
    expect(_flashOpacity(tester), 0);
  });

  testWidgets('reduced motion keeps the bell still', (tester) async {
    await tester.pumpWidget(_app(disableAnimations: true));
    await tester.pumpAndSettle();

    _setFeed(tester, <AppNotification>[_notification('quiet')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(_flashOpacity(tester), 0);
    expect(_bellColour(tester), _normalInk);

    // The badge still communicates the arrival.
    expect(
      find.byKey(const ValueKey<String>('home-notification-badge')),
      findsOneWidget,
    );
  });

  testWidgets('Arabic RTL and English LTR both keep the bell intact', (
    tester,
  ) async {
    for (final Locale locale in <Locale>[
      const Locale('en'),
      const Locale('ar'),
    ]) {
      await tester.pumpWidget(
        _app(
          locale: locale,
          initial: <AppNotification>[_notification('localized')],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('home-notification-badge')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the notifications page renders the shared live feed', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          notificationsProvider.overrideWith(
            (ref) => <AppNotification>[_notification('feed')],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const NotificationsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Booking feed'), findsOneWidget);
    expect(find.text('Your trip update feed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
