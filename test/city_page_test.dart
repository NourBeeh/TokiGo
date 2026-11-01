import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/presentation/pages/city_page.dart';

/// The Discover city tile opens this page instead of a pre-filtered search.
///
/// What is pinned here:
/// * the city's own facts (name, region, description, stay count) render;
/// * a city the provider described is not given a fabricated overview;
/// * a page opened without its item says so instead of inventing a city.
HomeItem _city({
  String title = 'Cairo',
  String? description,
  String? imageUrl,
  Map<String, dynamic> metadata = const <String, dynamic>{},
}) => HomeItem(
  id: 'city-cairo',
  type: HomeCardType.destination,
  title: title,
  description: description,
  imageUrl: imageUrl,
  metadata: metadata,
);

Widget _host(Widget child) =>
    MaterialApp(home: child, debugShowCheckedModeBanner: false);

void main() {
  testWidgets('renders the tapped city and its real facts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CityPage(
          city: _city(
            description: 'A thousand minarets on the Nile.',
            metadata: const <String, dynamic>{
              'region': 'Cairo Governorate',
              'staysCount': 12,
            },
          ),
        ),
      ),
    );

    expect(find.text('Cairo'), findsOneWidget);
    expect(find.text('Cairo Governorate'), findsOneWidget);
    expect(find.text('A thousand minarets on the Nile.'), findsOneWidget);
    expect(find.text('12 stays'), findsOneWidget);
    expect(find.text('Explore stays'), findsOneWidget);
  });

  testWidgets('a city with no description gets no invented overview', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(CityPage(city: _city())));

    // The fallback is an invitation, never a claim about the city.
    expect(
      find.text(
        'Find your stay in Cairo and explore everything the city has to offer.',
      ),
      findsOneWidget,
    );
    // Nothing the provider did not send: no region line, no stay count.
    expect(find.text('Cairo Governorate'), findsNothing);
    expect(find.textContaining('12 stays'), findsNothing);
  });

  testWidgets('a route opened without its city says so', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(const CityPage()));

    expect(find.text('City not found'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('shows the Commons credit for the city photo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CityPage(
          city: _city(
            imageUrl:
                'https://thumb.wikimedia.org/wikipedia/commons/thumb/d/db/'
                'Cairo_From_Tower_%28cropped%29.jpg/1280px-Cairo_From_Tower.jpg',
            metadata: const <String, dynamic>{
              'imageCredit': 'Wael El Sisi',
              'imageLicense': 'CC BY-SA 3.0',
              'imageSource':
                  'https://commons.wikimedia.org/wiki/File:Cairo_From_Tower.jpg',
            },
          ),
        ),
      ),
    );
    await tester.pump();

    // Author + licence, exactly as Commons states them — nothing invented.
    expect(find.text('Photo: Wael El Sisi · CC BY-SA 3.0'), findsOneWidget);
  });

  testWidgets('no photo credit without a credit the provider sent', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CityPage(
          city: _city(
            imageUrl: 'https://thumb.wikimedia.org/wikipedia/commons/x.jpg',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Photo:'), findsNothing);
  });
}
