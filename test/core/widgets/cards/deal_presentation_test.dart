import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:tokigo/core/widgets/cards/deal_presentation.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('DealPresentation', () {
    testWidgets('renders discount % badge when provided', (tester) async {
      await tester.pumpWidget(_wrap(DealPresentation(
        discountPercent: 30,
        currency: 'EGP',
      )));

      expect(find.text('30% OFF'), findsOneWidget);
      expect(find.byIcon(Icons.local_offer), findsOneWidget);
    });

    testWidgets('does not render discount badge when 0 or null', (tester) async {
      await tester.pumpWidget(_wrap(DealPresentation(
        discountPercent: 0,
      )));

      expect(find.textContaining('% OFF'), findsNothing);

      await tester.pumpWidget(_wrap(DealPresentation(
        discountPercent: null,
      )));

      expect(find.textContaining('% OFF'), findsNothing);
    });

    testWidgets('renders savings amount chip when provided', (tester) async {
      await tester.pumpWidget(_wrap(DealPresentation(
        savingsAmount: 2500,
        currency: 'EGP',
      )));

      expect(find.textContaining('Save 2,500'), findsOneWidget);
      expect(find.textContaining('EGP'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('does not render savings chip when 0 or null', (tester) async {
      await tester.pumpWidget(_wrap(DealPresentation(
        savingsAmount: 0,
      )));

      expect(find.textContaining('Save'), findsNothing);

      await tester.pumpWidget(_wrap(DealPresentation(
        savingsAmount: null,
      )));

      expect(find.textContaining('Save'), findsNothing);
    });

    testWidgets('renders validity date when validUntil is future', (tester) async {
      final future = DateTime.now().add(const Duration(days: 30));
      await tester.pumpWidget(_wrap(DealPresentation(
        validUntil: future.toIso8601String(),
      )));

      expect(find.textContaining('Valid until'), findsOneWidget);
      // Should contain month abbreviation and day
      expect(find.textContaining(DateFormat.MMMd().format(future)), findsOneWidget);
    });

    testWidgets('does not render validity when past', (tester) async {
      final past = DateTime.now().subtract(const Duration(days: 1));
      await tester.pumpWidget(_wrap(DealPresentation(
        validUntil: past.toIso8601String(),
      )));

      expect(find.textContaining('Valid until'), findsNothing);
    });

    testWidgets('does not render validity when invalid date', (tester) async {
      await tester.pumpWidget(_wrap(DealPresentation(
        validUntil: 'invalid-date',
      )));

      expect(find.textContaining('Valid until'), findsNothing);
    });

    testWidgets('does not render validity when null', (tester) async {
      await tester.pumpWidget(_wrap(DealPresentation(
        validUntil: null,
      )));

      expect(find.textContaining('Valid until'), findsNothing);
    });

    testWidgets('respects showDiscountBadge flag', (tester) async {
      await tester.pumpWidget(_wrap(DealPresentation(
        discountPercent: 30,
        showDiscountBadge: false,
      )));

      expect(find.text('30% OFF'), findsNothing);
    });

    testWidgets('respects showSavingsChip flag', (tester) async {
      await tester.pumpWidget(_wrap(DealPresentation(
        savingsAmount: 2500,
        showSavingsChip: false,
      )));

      expect(find.textContaining('Save'), findsNothing);
    });

    testWidgets('respects showValidity flag', (tester) async {
      final future = DateTime.now().add(const Duration(days: 30));
      await tester.pumpWidget(_wrap(DealPresentation(
        validUntil: future.toIso8601String(),
        showValidity: false,
      )));

      expect(find.textContaining('Valid until'), findsNothing);
    });

    testWidgets('renders nothing when all flags false', (tester) async {
      await tester.pumpWidget(_wrap(DealPresentation(
        discountPercent: 30,
        savingsAmount: 2500,
        validUntil: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        showDiscountBadge: false,
        showSavingsChip: false,
        showValidity: false,
      )));

      expect(find.byType(DealPresentation), findsOneWidget);
      expect(find.text('30% OFF'), findsNothing);
      expect(find.textContaining('Save'), findsNothing);
      expect(find.textContaining('Valid until'), findsNothing);
    });

    testWidgets('renders all components when all data provided', (tester) async {
      final future = DateTime.now().add(const Duration(days: 30));
      await tester.pumpWidget(_wrap(DealPresentation(
        discountPercent: 25,
        savingsAmount: 1500,
        validUntil: future.toIso8601String(),
        currency: 'EGP',
      )));

      expect(find.text('25% OFF'), findsOneWidget);
      expect(find.textContaining('Save 1,500'), findsOneWidget);
      expect(find.textContaining('EGP'), findsOneWidget);
      expect(find.textContaining('Valid until'), findsOneWidget);
    });

    testWidgets('dark mode renders without errors', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: DealPresentation(
          discountPercent: 20,
          savingsAmount: 1000,
          validUntil: DateTime.now().add(const Duration(days: 10)).toIso8601String(),
        )),
      ));

      expect(find.byType(DealPresentation), findsOneWidget);
    });
  });
}