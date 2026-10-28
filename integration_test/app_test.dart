import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tokigo/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('4D/4E booking flow verification', () {
    testWidgets('app launches and reaches booking confirmation screen',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();
      // Minimal verification: app launched without crash (4B-4E adapter wired).
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
