import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/geo/city_catalog.dart';
import 'package:tokigo/core/geo/city_providers.dart';
import 'package:tokigo/core/geo/city_selection.dart';
import 'package:tokigo/core/geo/country_options.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/pressable.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Opens the single customer-facing City Selection picker.
///
/// The catalog comes from the backend (`GET /geo/cities`) and is cached on
/// disk, so the picker works offline after the first successful load. Choosing
/// a city stores a MANUAL selection that background detection can never
/// overwrite.
Future<void> showCitySelectionSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) => const CitySelectionSheet(),
  );
}

/// The city picker: search, the current selection, and honest loading /
/// unavailable / empty states. It exposes no GPS, IP or "automatic" control —
/// the customer picks a city or closes the sheet.
class CitySelectionSheet extends ConsumerStatefulWidget {
  const CitySelectionSheet({super.key});

  @override
  ConsumerState<CitySelectionSheet> createState() => _CitySelectionSheetState();
}

class _CitySelectionSheetState extends ConsumerState<CitySelectionSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final Locale locale = Localizations.localeOf(context);
    final AsyncValue<CityCatalog?> catalog = ref.watch(cityCatalogProvider);
    final String? currentId = ref.watch(citySelectionProvider).effective?.city.id;
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: context.tokigoColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Header(title: l10n.cityPickerTitle),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: _SearchField(
                  controller: _search,
                  hint: l10n.cityPickerSearch,
                  onChanged: (String value) =>
                      setState(() => _query = value),
                ),
              ),
              Flexible(
                child: catalog.when(
                  loading: () => _MessageState(
                    title: l10n.cityPickerLoading,
                    loading: true,
                  ),
                  error: (Object _, StackTrace _) => _UnavailableState(
                    title: l10n.cityPickerUnavailableTitle,
                    body: l10n.cityPickerUnavailableBody,
                    retryLabel: l10n.cityPickerRetry,
                    onRetry: () => ref.invalidate(cityCatalogProvider),
                  ),
                  data: (CityCatalog? value) {
                    if (value == null) {
                      return _UnavailableState(
                        title: l10n.cityPickerUnavailableTitle,
                        body: l10n.cityPickerUnavailableBody,
                        retryLabel: l10n.cityPickerRetry,
                        onRetry: () => ref.invalidate(cityCatalogProvider),
                      );
                    }
                    final List<CityOption> results = value.search(
                      _query,
                      countryName: (String code) =>
                          countryNameForCode(code, locale) ?? code,
                    );
                    if (results.isEmpty) {
                      return _MessageState(
                        title: l10n.cityPickerEmptyTitle,
                        body: l10n.cityPickerEmptyBody,
                      );
                    }
                    return _CityList(
                      cities: results,
                      currentId: currentId,
                      locale: locale,
                      currentLabel: l10n.cityPickerCurrent,
                      onSelected: _select,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _select(CityOption city) async {
    await ref.read(citySelectionProvider.notifier).selectManual(city);
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).brightness == Brightness.dark
        ? AppTypography.forDark()
        : AppTypography.forLight();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.tokigoColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              title,
              style: typography.title.copyWith(
                color: context.tokigoColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(color: context.tokigoColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.tokigoColors.textTertiary),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: context.tokigoColors.textSecondary,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                icon: Icon(
                  Icons.close_rounded,
                  color: context.tokigoColors.textSecondary,
                ),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: context.tokigoColors.surfaceSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: context.tokigoColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: context.tokigoColors.textPrimary),
        ),
      ),
    );
  }
}

class _CityList extends StatelessWidget {
  const _CityList({
    required this.cities,
    required this.currentId,
    required this.locale,
    required this.currentLabel,
    required this.onSelected,
  });

  final List<CityOption> cities;
  final String? currentId;
  final Locale locale;
  final String currentLabel;
  final ValueChanged<CityOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).brightness == Brightness.dark
        ? AppTypography.forDark()
        : AppTypography.forLight();
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      itemCount: cities.length,
      itemBuilder: (BuildContext context, int index) {
        final CityOption city = cities[index];
        final bool selected = city.id == currentId;
        final String country =
            countryNameForCode(city.countryCode, locale) ?? city.countryCode;
        return Semantics(
          button: true,
          selected: selected,
          label: selected ? '$currentLabel: ${city.name}, $country' : null,
          child: Pressable.wrap(
            child: InkWell(
              onTap: () => onSelected(city),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.minimumTapTarget,
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              city.name,
                              style: typography.body.copyWith(
                                color: context.tokigoColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              '$country · ${city.currency}',
                              style: typography.caption.copyWith(
                                color: context.tokigoColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: context.tokigoColors.primary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.title,
    this.body,
    this.loading = false,
  });

  final String title;
  final String? body;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).brightness == Brightness.dark
        ? AppTypography.forDark()
        : AppTypography.forLight();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (loading) ...<Widget>[
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: typography.body.copyWith(
              color: context.tokigoColors.textPrimary,
            ),
          ),
          if (body != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: typography.caption.copyWith(
                color: context.tokigoColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnavailableState extends StatelessWidget {
  const _UnavailableState({
    required this.title,
    required this.body,
    required this.retryLabel,
    required this.onRetry,
  });

  final String title;
  final String body;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).brightness == Brightness.dark
        ? AppTypography.forDark()
        : AppTypography.forLight();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.public_off_rounded,
            size: 28,
            color: context.tokigoColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: typography.body.copyWith(
              color: context.tokigoColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            textAlign: TextAlign.center,
            style: typography.caption.copyWith(
              color: context.tokigoColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}
