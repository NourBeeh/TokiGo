import 'package:flutter/material.dart';

/// Renders a date in the language the app is currently showing.
///
/// The search forms used to format their dates with the default (English)
/// locale, so an Arabic screen displayed "Mon, Oct 26". The Material
/// localizations the app already ships carry the right symbols for the chosen
/// locale — the same shape the date picker uses, so the field and the picker
/// agree on the reading of the date.
String localizedMediumDate(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatMediumDate(date);

/// Short "7 Dec" form, used where a full date would not fit (a CTA bar, a
/// summary line) but the month still has to read in the app's language.
String localizedShortDate(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatShortMonthDay(date);
