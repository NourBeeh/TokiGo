import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/geo/country_options.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

Future<void> showCountrySelectionSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  final locale = Localizations.localeOf(context);
  final currentCode =
      ref.read(manualCountryCodeProvider) ??
      ref.read(geoCountryProvider).asData?.value?.countryCode;
  final selected = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.72,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.locationChooseCountry,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: manualCountryOptions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = manualCountryOptions[index];
                  final isSelected = option.code == currentCode;
                  return ListTile(
                    title: Text(option.localizedName(locale)),
                    subtitle: Text('${option.code} · ${option.airportCode}'),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.brand,
                          )
                        : null,
                    onTap: () => Navigator.of(sheetContext).pop(option.code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (selected == null) return;

  try {
    await ref.read(manualCountryCodeProvider.notifier).selectCountry(selected);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.locationCountrySaveFailed)));
  }
}
