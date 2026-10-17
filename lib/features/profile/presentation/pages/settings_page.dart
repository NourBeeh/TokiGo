import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wetravellers/core/theme/app_colors.dart';
import 'package:wetravellers/core/theme/app_radius.dart';
import 'package:wetravellers/core/theme/app_spacing.dart';
import 'package:wetravellers/core/theme/app_typography.dart';
import 'package:wetravellers/shared/providers/locale_provider.dart';
import 'package:wetravellers/l10n/app_localizations.dart';

/// Settings — language and currency preferences.
///
/// Light/dark is intentionally absent: the design language is light-only.
/// The picked locale persists in [localeProvider] (Hive persistence lands
/// with the storage phase).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const List<String> _currencies = <String>[
    'USD',
    'EUR',
    'EGP',
    'SAR',
    'AED',
    'GBP',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                    tooltip: l10n.back,
                  ),
                  Text(
                    l10n.settings,
                    style: typography.title.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: Text(
                      l10n.adminPanel,
                      style: typography.bodyLargeMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    onTap: () => context.push('/admin'),
                  ),
                  const Divider(),
                  Text(
                    l10n.language,
                    style: typography.bodyLargeMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _OptionTile(
                    label: 'English',
                    selected: locale.languageCode == 'en',
                    onTap: () => ref.read(localeProvider.notifier).state =
                        const Locale('en'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _OptionTile(
                    label: 'العربية',
                    selected: locale.languageCode == 'ar',
                    onTap: () => ref.read(localeProvider.notifier).state =
                        const Locale('ar'),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    l10n.currency,
                    style: typography.bodyLargeMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final code in _currencies)
                        _CurrencyChip(
                          code: code,
                          selected: code == currency,
                          onTap: () => ref
                              .read(currencyProvider.notifier)
                              .state = code,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.outline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: typography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: AppColors.brand,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Material(
      color: selected ? AppColors.brand : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.outline,
            ),
          ),
          child: Text(
            code,
            style: typography.bodyMedium.copyWith(
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
