import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/widgets/app_back_button.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The shared page header must mirror as a whole: the back control sits on the
/// START edge (left in LTR, right in RTL), with the description hugging it and
/// any trailing action on the END edge.
///
/// Regression: the header used to carry an explicit RTL branch that REVERSED
/// the children instead of letting [Directionality] mirror the row, which left
/// the back chevron on the LEFT in Arabic next to a right-aligned title — a
/// right-pointing arrow on the wrong side.
Future<void> _pump(
  WidgetTester tester, {
  required Locale locale,
  String? trailingLabel,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: AppPageHeader(
          subtitle: 'Page description',
          trailing: trailingLabel == null ? null : Text(trailingLabel),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Horizontal centre of the back control relative to the description.
double _backCenter(WidgetTester tester) =>
    tester.getCenter(find.byType(AppBackButton)).dx;

double _descriptionCenter(WidgetTester tester) =>
    tester.getCenter(find.text('Page description')).dx;

void main() {
  testWidgets('LTR: back control is on the left of the description', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, locale: const Locale('en'), trailingLabel: 'Action');

    expect(_backCenter(tester), lessThan(_descriptionCenter(tester)));
    // The trailing action is on the END edge (right in LTR).
    expect(
      tester.getCenter(find.text('Action')).dx,
      greaterThan(_descriptionCenter(tester)),
    );
  });

  testWidgets('RTL: back control mirrors to the RIGHT of the description', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, locale: const Locale('ar'), trailingLabel: 'إجراء');

    expect(Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.rtl);
    expect(_backCenter(tester), greaterThan(_descriptionCenter(tester)));
    // The trailing action mirrors to the END edge (left in RTL).
    expect(
      tester.getCenter(find.text('إجراء')).dx,
      lessThan(_descriptionCenter(tester)),
    );
  });
}
