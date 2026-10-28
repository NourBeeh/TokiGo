import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/features/search/domain/country_airport_suggestions.dart';

/// One suggestion entry shared by every picker sheet.
@immutable
class PickerEntry {
  const PickerEntry({
    required this.code,
    required this.name,
    this.country,
    this.countryCode,
    this.isPopular = false,
  });

  /// IATA / city key used in the search form.
  final String code;

  /// Display name ("Cairo International", "Downtown Dubai"…).
  final String name;

  final String? country;
  final String? countryCode;

  final bool isPopular;
}

const List<PickerEntry> kAirports = <PickerEntry>[
  PickerEntry(
    code: 'CAI',
    name: 'Cairo International',
    country: 'Egypt',
    isPopular: true,
  ),
  PickerEntry(
    code: 'DXB',
    name: 'Dubai International',
    country: 'UAE',
    isPopular: true,
  ),
  PickerEntry(
    code: 'RUH',
    name: 'Riyadh King Khalid',
    country: 'Saudi Arabia',
    isPopular: true,
  ),
  PickerEntry(
    code: 'JED',
    name: 'Jeddah King Abdulaziz',
    country: 'Saudi Arabia',
    isPopular: true,
  ),
  PickerEntry(code: 'HRG', name: 'Hurghada International', country: 'Egypt'),
  PickerEntry(code: 'SSH', name: 'Sharm El Sheikh', country: 'Egypt'),
  PickerEntry(code: 'LXR', name: 'Luxor International', country: 'Egypt'),
  PickerEntry(code: 'ASW', name: 'Aswan International', country: 'Egypt'),
  PickerEntry(code: 'HBE', name: 'Alexandria Borg El Arab', country: 'Egypt'),
  PickerEntry(
    code: 'LHR',
    name: 'London Heathrow',
    country: 'United Kingdom',
    isPopular: true,
  ),
  PickerEntry(code: 'CDG', name: 'Paris Charles de Gaulle', country: 'France'),
  PickerEntry(
    code: 'IST',
    name: 'Istanbul Airport',
    country: 'Turkey',
    isPopular: true,
  ),
  PickerEntry(code: 'FCO', name: 'Rome Fiumicino', country: 'Italy'),
  PickerEntry(
    code: 'JFK',
    name: 'New York John F. Kennedy',
    country: 'USA',
    isPopular: true,
  ),
  PickerEntry(code: 'DOH', name: 'Doha Hamad', country: 'Qatar'),
  PickerEntry(code: 'AMM', name: 'Amman Queen Alia', country: 'Jordan'),
  PickerEntry(code: 'ATH', name: 'Athens International', country: 'Greece'),
  PickerEntry(code: 'BKK', name: 'Bangkok Suvarnabhumi', country: 'Thailand'),
  PickerEntry(code: 'SIN', name: 'Singapore Changi', country: 'Singapore'),
  PickerEntry(code: 'HND', name: 'Tokyo Haneda', country: 'Japan'),
];

/// Best-known primary airport from the app's curated picker catalogue.
/// Country is only a starting suggestion; travellers can always change it.
PickerEntry? suggestedAirportForCountryCode(String? countryCode) {
  final airportCode = suggestedAirportCodeForCountry(countryCode);
  if (airportCode == null) return null;
  for (final airport in kAirports) {
    if (airport.code == airportCode) return airport;
  }
  return null;
}

const List<PickerEntry> kCities = <PickerEntry>[
  PickerEntry(
    code: 'cairo',
    name: 'Cairo',
    country: 'Egypt',
    countryCode: 'EG',
    isPopular: true,
  ),
  PickerEntry(
    code: 'dubai',
    name: 'Dubai',
    country: 'UAE',
    countryCode: 'AE',
    isPopular: true,
  ),
  PickerEntry(
    code: 'riyadh',
    name: 'Riyadh',
    country: 'Saudi Arabia',
    countryCode: 'SA',
    isPopular: true,
  ),
  PickerEntry(
    code: 'jeddah',
    name: 'Jeddah',
    country: 'Saudi Arabia',
    countryCode: 'SA',
  ),
  PickerEntry(
    code: 'hurghada',
    name: 'Hurghada',
    country: 'Egypt',
    countryCode: 'EG',
  ),
  PickerEntry(
    code: 'sharm el sheikh',
    name: 'Sharm El Sheikh',
    country: 'Egypt',
    countryCode: 'EG',
  ),
  PickerEntry(
    code: 'luxor',
    name: 'Luxor',
    country: 'Egypt',
    countryCode: 'EG',
  ),
  PickerEntry(
    code: 'aswan',
    name: 'Aswan',
    country: 'Egypt',
    countryCode: 'EG',
  ),
  PickerEntry(
    code: 'alexandria',
    name: 'Alexandria',
    country: 'Egypt',
    countryCode: 'EG',
  ),
  PickerEntry(
    code: 'istanbul',
    name: 'Istanbul',
    country: 'Turkey',
    countryCode: 'TR',
    isPopular: true,
  ),
  PickerEntry(
    code: 'london',
    name: 'London',
    country: 'United Kingdom',
    countryCode: 'GB',
    isPopular: true,
  ),
  PickerEntry(
    code: 'paris',
    name: 'Paris',
    country: 'France',
    countryCode: 'FR',
  ),
  PickerEntry(code: 'rome', name: 'Rome', country: 'Italy', countryCode: 'IT'),
  PickerEntry(
    code: 'athens',
    name: 'Athens',
    country: 'Greece',
    countryCode: 'GR',
  ),
  PickerEntry(code: 'doha', name: 'Doha', country: 'Qatar', countryCode: 'QA'),
  PickerEntry(
    code: 'amman',
    name: 'Amman',
    country: 'Jordan',
    countryCode: 'JO',
  ),
  PickerEntry(
    code: 'new york',
    name: 'New York',
    country: 'USA',
    countryCode: 'US',
  ),
  PickerEntry(
    code: 'bangkok',
    name: 'Bangkok',
    country: 'Thailand',
    countryCode: 'TH',
  ),
];

/// Premium autocomplete bottom sheet for airports/cities.
///
/// Opens over any search form; returns the picked [PickerEntry] through
/// [onSelected]. Search filters by code, name and country.
Future<void> showPickerSheet(
  BuildContext context, {
  required String title,
  required List<PickerEntry> entries,
  required ValueChanged<PickerEntry> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        _PickerSheet(title: title, entries: entries, onSelected: onSelected),
  );
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.entries,
    required this.onSelected,
  });

  final String title;
  final List<PickerEntry> entries;
  final ValueChanged<PickerEntry> onSelected;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PickerEntry> get _filtered {
    if (_query.isEmpty) return widget.entries;
    final q = _query.toLowerCase();
    return widget.entries
        .where(
          (e) =>
              e.code.toLowerCase().contains(q) ||
              e.name.toLowerCase().contains(q) ||
              (e.country?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final results = _filtered;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.title,
                    style: typography.title.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    autofocus: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: l10n?.pickerSearchHint ?? 'Search…',
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxxl),
                      child: Text(
                        l10n?.pickerNoMatches ?? 'No matches',
                        style: typography.body.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final entry = results[index];
                        return _PickerTile(
                          entry: entry,
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onSelected(entry);
                          },
                        );
                      },
                    ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.entry, required this.onTap});

  final PickerEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brandContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text(
                    entry.code.length == 3
                        ? entry.code
                        : entry.code.substring(0, 2).toUpperCase(),
                    style: typography.captionSemibold.copyWith(
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            entry.name,
                            style: typography.bodyLargeMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (entry.isPopular)
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppColors.starFill,
                          ),
                      ],
                    ),
                    if (entry.country != null)
                      Text(
                        '${entry.country} · ${entry.code}',
                        style: typography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
