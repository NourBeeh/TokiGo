import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/shared/providers/locale_provider.dart';

/// The app's language sheet — Arabic / English.
///
/// The language is a **device-level** preference, not an account one: a
/// guest must be able to switch it too, which is why this lives outside the
/// account surfaces.
Future<void> showLanguageSheet(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final ProviderContainer container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  final Locale current = container.read(localeProvider);
  final Locale? chosen = await showModalBottomSheet<Locale>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadiusDirectional.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
    ),
    builder: (BuildContext sheetContext) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              l10n.language,
              style: AppTypography.forLight().title.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          for (final Locale locale in const <Locale>[
            Locale('ar'),
            Locale('en'),
          ])
            InkWell(
              onTap: () => Navigator.of(sheetContext).pop(locale),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        locale.languageCode == 'ar' ? 'العربية' : 'English',
                        style: AppTypography.forLight().body.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (locale.languageCode == current.languageCode)
                      const Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: AppColors.brand,
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
  if (chosen != null) {
    container.read(localeProvider.notifier).setLocale(chosen);
  }
}
