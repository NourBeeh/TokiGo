import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/app/config/app_config.dart';
import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/geo/country_options.dart';
import 'package:tokigo/core/geo/country_selection_sheet.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/shared/providers/locale_provider.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Settings — the account, the preferences, the language, the app and the
/// one destructive action.
///
/// Light/dark is intentionally absent: the design language is light-only.
/// The picked locale persists in [localeProvider] (Hive persistence lands
/// with the storage phase).
///
/// Geometry (doc 23 §6):
/// * group header — `label` 11/600 `textTertiary`, tracking +0.3, `xl` 24 above;
/// * group card — `surface`, `lg` 18, 1px `outline`, clipped;
/// * row — min height **56**, icon 20 `textSecondary`, label `body` 15/400;
/// * value row — the muted value is `caption` 13/400 `textSecondary`, with a
///   chevron;
/// * destructive row — the label is `danger`, and it carries no chevron;
/// * language row — opens a sheet with AR/EN, reflecting the real [Locale].
///
/// **Every row here does something real.** There is no toggle, because the app
/// owns no boolean preference to toggle: a switch that changes nothing is a
/// dead control.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  /// The currencies the app can display. Real ISO codes — the prices
  /// themselves always come from the provider.
  static const List<String> _currencies = <String>[
    'USD',
    'EUR',
    'EGP',
    'SAR',
    'AED',
    'GBP',
  ];

  /// The shipped languages. Their names are endonyms — a language is called
  /// by its own name in every language.
  static const List<Locale> _languages = <Locale>[Locale('en'), Locale('ar')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final currency = ref.watch(currencyProvider);
    final user = ref.watch(authUserProvider);
    final country =
        ref.watch(manualCountryCodeProvider) ??
        ref.watch(geoCountryProvider).asData?.value?.countryCode;
    final countryName =
        countryNameForCode(country, locale) ?? l10n.settingsCountryNotSet;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: AiEntranceAnimation(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(child: AppPageHeader(title: l10n.settings)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    // Doc 23 §0 — the page ends with `xxl` 32 plus the safe
                    // area.
                    AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // ---- Account -------------------------------------
                      // Only an account can act here — the row used to be
                      // offered to everyone, which is a door onto a forbidden
                      // page.
                      if (user != null) ...<Widget>[
                        _GroupHeader(label: l10n.settingsAccount),
                        _GroupCard(
                          children: <Widget>[
                            _SettingsRow(
                              icon: Icons.person_outline_rounded,
                              label: _identity(user.displayName, user.email),
                              subtitle: _identitySubtitle(
                                user.displayName,
                                user.email,
                              ),
                            ),
                            if (user.isAdmin) ...<Widget>[
                              const _GroupDivider(),
                              _SettingsRow(
                                icon: Icons.admin_panel_settings_outlined,
                                label: l10n.adminPanel,
                                onTap: () => context.push('/admin'),
                              ),
                            ],
                          ],
                        ),
                      ],

                      // ---- Preferences ---------------------------------
                      _GroupHeader(label: l10n.settingsPreferences),
                      _GroupCard(
                        children: <Widget>[
                          _SettingsRow(
                            icon: Icons.public_rounded,
                            label: l10n.settingsCountry,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                _MutedValue(text: countryName),
                                const SizedBox(width: AppSpacing.xs),
                                const _Chevron(),
                              ],
                            ),
                            onTap: () =>
                                showCountrySelectionSheet(context, ref),
                          ),
                          const _GroupDivider(),
                          _SettingsRow(
                            icon: Icons.payments_outlined,
                            label: l10n.currency,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                _MutedValue(text: currency),
                                const SizedBox(width: AppSpacing.xs),
                                const _Chevron(),
                              ],
                            ),
                            onTap: () => _pickCurrency(context, ref),
                          ),
                        ],
                      ),

                      // ---- Language ------------------------------------
                      _GroupHeader(label: l10n.language),
                      _GroupCard(
                        children: <Widget>[
                          _SettingsRow(
                            icon: Icons.translate_rounded,
                            label: l10n.settingsAppLanguage,
                            subtitle: _LanguageOptions(current: locale),
                            trailing: const _Chevron(),
                            onTap: () => _pickLanguage(context, ref),
                          ),
                        ],
                      ),

                      // ---- About ---------------------------------------
                      _GroupHeader(label: l10n.settingsAbout),
                      _GroupCard(
                        children: <Widget>[
                          _SettingsRow(
                            icon: Icons.info_outline_rounded,
                            label: l10n.settingsVersion,
                            trailing: _MutedValue(
                              text: AppConfig.appVersionLabel,
                            ),
                          ),
                        ],
                      ),

                      // ---- Danger zone ---------------------------------
                      if (user != null) ...<Widget>[
                        _GroupHeader(label: l10n.settingsDangerZone),
                        _GroupCard(
                          children: <Widget>[
                            _SettingsRow(
                              icon: Icons.logout_rounded,
                              label: l10n.signOut,
                              labelColor: AppColors.danger,
                              onTap: () => ref
                                  .read(authControllerProvider.notifier)
                                  .logout(),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The language sheet: AR/EN, with the real [Locale] checked.
  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final Locale current = ref.read(localeProvider);
    final Locale? chosen = await showModalBottomSheet<Locale>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => _OptionSheet<Locale>(
        title: l10n.language,
        options: _languages
            .map(
              (Locale locale) => _Option<Locale>(
                value: locale,
                label: _languageName(locale),
                selected: locale.languageCode == current.languageCode,
              ),
            )
            .toList(growable: false),
      ),
    );
    if (chosen == null) return;
    ref.read(localeProvider.notifier).setLocale(chosen);
  }

  /// The currency sheet: the real codes, the current one checked.
  Future<void> _pickCurrency(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final String current = ref.read(currencyProvider);
    final String? chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => _OptionSheet<String>(
        title: l10n.currency,
        options: _currencies
            .map(
              (String code) => _Option<String>(
                value: code,
                label: code,
                selected: code == current,
              ),
            )
            .toList(growable: false),
      ),
    );
    if (chosen == null) return;
    ref.read(currencyProvider.notifier).state = chosen;
  }

  /// The endonym of a shipped language.
  static String _languageName(Locale locale) =>
      locale.languageCode == 'ar' ? 'العربية' : 'English';

  /// Who the session belongs to — the name the account carries, or the email
  /// when it carries no name.
  static String _identity(String? displayName, String email) {
    final String name = displayName?.trim() ?? '';
    return name.isNotEmpty ? name : email.trim();
  }

  /// The email under the name — only when it adds something.
  static Widget? _identitySubtitle(String? displayName, String email) {
    final String name = displayName?.trim() ?? '';
    final String address = email.trim();
    if (name.isEmpty || address.isEmpty) return null;
    return _MutedValue(text: address);
  }
}

/// The group header — `label` 11/600 `textTertiary`, tracking +0.3.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.xl,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        label,
        style: typography.label.copyWith(color: AppColors.textTertiary),
      ),
    );
  }
}

/// The group card — `surface`, `lg` 18, 1px `outline`, clipped.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

/// The hairline between two rows of a group card.
class _GroupDivider extends StatelessWidget {
  const _GroupDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: AppSpacing.lg,
      endIndent: AppSpacing.lg,
      color: AppColors.divider,
    );
  }
}

/// One settings row — at least 56 tall, an icon column, the label and the
/// trailing control.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    this.icon,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.labelColor,
  });

  /// The 20px glyph at the start of the row. Absent on the destructive row.
  final IconData? icon;

  /// The label — `body` 15/400.
  final String label;

  /// An optional second line under the label.
  final Widget? subtitle;

  /// The trailing control (a value, a chevron, a switch…).
  final Widget? trailing;

  /// What the row does. A row without an action is a label, not a control.
  final VoidCallback? onTap;

  /// The label's ink — `danger` for the destructive row.
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: typography.body.copyWith(
                      color: labelColor ?? AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    subtitle!,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// A muted value — `caption` 13/400 `textSecondary`.
class _MutedValue extends StatelessWidget {
  const _MutedValue({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.forLight().caption.copyWith(
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// The row chevron — it points forward in the reading direction.
class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(
      rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
      size: 20,
      color: AppColors.textTertiary,
    );
  }
}

/// The language line under the "Language" label: both shipped languages, with
/// the real one checked. The sheet is the interactive picker; this line says
/// what the app speaks right now.
class _LanguageOptions extends StatelessWidget {
  const _LanguageOptions({required this.current});

  final Locale current;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final Locale locale in SettingsPage._languages) ...<Widget>[
          Text(
            locale.languageCode == 'ar' ? 'العربية' : 'English',
            style: typography.caption.copyWith(color: AppColors.textSecondary),
          ),
          if (locale.languageCode == current.languageCode) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: AppColors.brand,
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// One option inside a sheet.
class _Option<T> {
  const _Option({
    required this.value,
    required this.label,
    required this.selected,
  });

  final T value;
  final String label;
  final bool selected;
}

/// The shared picker sheet — a title and a list of options, the current one
/// checked.
class _OptionSheet<T> extends StatelessWidget {
  const _OptionSheet({required this.title, required this.options});

  final String title;
  final List<_Option<T>> options;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              title,
              style: typography.title.copyWith(color: AppColors.textPrimary),
            ),
          ),
          for (final _Option<T> option in options)
            InkWell(
              onTap: () => Navigator.of(context).pop(option.value),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          option.label,
                          style: typography.body.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (option.selected)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: AppColors.brand,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
