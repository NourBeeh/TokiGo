import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/core/widgets/pressable.dart';
import 'package:tokigo/features/home/presentation/destination_localization.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';
import 'package:tokigo/features/home/presentation/widgets/home_discovery_stay_card.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

enum ExploreCityFilter {
  all,
  youth,
  families,
  honeymoon,
  beach,
  nature,
  city,
  shopping,
  snow,
}

List<HomeItem> discoverCitiesFromSections(List<HomeSection> sections) {
  final Map<String, HomeItem> cities = <String, HomeItem>{};
  for (final HomeItem item in sections.expand((section) => section.items)) {
    if (item.type != HomeCardType.destination) continue;
    final String key = item.id.trim().isNotEmpty
        ? item.id.trim()
        : '${item.title.trim().toLowerCase()}|${_regionOf(item).toLowerCase()}';
    cities.putIfAbsent(key, () => item);
  }
  return cities.values.toList(growable: false);
}

List<HomeItem> filterDiscoverCities(
  List<HomeItem> cities, {
  required String query,
  required ExploreCityFilter filter,
  AppLocalizations? l10n,
  String languageCode = 'en',
}) {
  final String normalizedQuery = query.trim().toLowerCase();
  return cities
      .where((HomeItem item) {
        if (normalizedQuery.isNotEmpty) {
          final String searchable = <String>[
            item.title,
            localizedDestinationText(
              item,
              DestinationTextField.title,
              l10n: l10n,
              languageCode: languageCode,
            ),
            item.subtitle ?? '',
            localizedDestinationText(
              item,
              DestinationTextField.subtitle,
              l10n: l10n,
              languageCode: languageCode,
            ),
            item.description ?? '',
            localizedDestinationText(
              item,
              DestinationTextField.description,
              l10n: l10n,
              languageCode: languageCode,
            ),
            _regionOf(item),
            localizedDestinationText(
              item,
              DestinationTextField.region,
              l10n: l10n,
              languageCode: languageCode,
            ),
            item.metadata['city']?.toString() ?? '',
            item.metadata['country']?.toString() ?? '',
          ].join(' ').toLowerCase();
          if (!searchable.contains(normalizedQuery)) return false;
        }

        return switch (filter) {
          ExploreCityFilter.all => true,
          ExploreCityFilter.youth => _hasAudience(item, <String>{
            'youth',
            'young',
            'young adults',
            'youthful',
            'شباب',
            'شبابي',
          }),
          ExploreCityFilter.families => _hasAudience(item, <String>{
            'family',
            'families',
            'family friendly',
            'عائلات',
            'عائلي',
          }),
          ExploreCityFilter.honeymoon => _hasAudience(item, <String>{
            'honeymoon',
            'romantic',
            'شهر عسل',
            'رومانسي',
          }),
          ExploreCityFilter.beach => _hasMood(item, 'beach'),
          ExploreCityFilter.nature => _hasMood(item, 'nature'),
          ExploreCityFilter.city => _hasMood(item, 'city'),
          ExploreCityFilter.shopping => _hasMood(item, 'shopping'),
          ExploreCityFilter.snow => _hasMood(item, 'snow'),
        };
      })
      .toList(growable: false);
}

bool _hasAudience(HomeItem item, Set<String> accepted) {
  final List<String> values = <String>[
    ...item.tags,
    ..._metadataStrings(item.metadata['audiences']),
    ..._metadataStrings(item.metadata['audience']),
    ..._metadataStrings(item.metadata['targetAudience']),
    ..._metadataStrings(item.metadata['travelStyles']),
  ];
  return values.any((String value) => accepted.contains(_normalize(value)));
}

bool _hasMood(HomeItem item, String mood) {
  final List<String> values = <String>[
    ...item.tags,
    ..._metadataStrings(item.metadata['moods']),
  ];
  return values.any((String value) => _normalize(value) == mood);
}

List<String> _metadataStrings(Object? value) {
  if (value is Iterable) {
    return value.map((Object? item) => item?.toString() ?? '').toList();
  }
  if (value is String && value.trim().isNotEmpty) return <String>[value];
  return const <String>[];
}

String _normalize(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[_-]+'), ' ');

String _regionOf(HomeItem item) =>
    (item.metadata['region'] ?? item.metadata['country'] ?? '').toString();

class ExploreCitiesPage extends ConsumerStatefulWidget {
  const ExploreCitiesPage({super.key});

  @override
  ConsumerState<ExploreCitiesPage> createState() => _ExploreCitiesPageState();
}

class _ExploreCitiesPageState extends ConsumerState<ExploreCitiesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  ExploreCityFilter _filter = ExploreCityFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final HomeState state = ref.watch(homeControllerProvider);
    final List<HomeItem> cities = discoverCitiesFromSections(state.sections);
    final List<HomeItem> visibleCities = filterDiscoverCities(
      cities,
      query: _query,
      filter: _filter,
      l10n: l10n,
      languageCode: Localizations.localeOf(context).languageCode,
    );

    return Scaffold(
      backgroundColor: context.tokigoColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            AppPageHeader(
              subtitle: l10n.exploreCitiesTitle,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: (String value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: l10n.exploreCitySearch,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : Pressable.wrap(
                          child: IconButton(
                            tooltip: l10n.clearAll,
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: <Widget>[
                  for (final ExploreCityFilter filter
                      in ExploreCityFilter.values)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.sm,
                      ),
                      child: ChoiceChip(
                        label: Text(_filterLabel(l10n, filter)),
                        selected: _filter == filter,
                        onSelected: (bool selected) {
                          if (selected) setState(() => _filter = filter);
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _buildCities(
                state: state,
                cities: cities,
                visibleCities: visibleCities,
                l10n: l10n,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCities({
    required HomeState state,
    required List<HomeItem> cities,
    required List<HomeItem> visibleCities,
    required AppLocalizations l10n,
  }) {
    if (visibleCities.isEmpty) {
      if (state.status == HomeStatus.loading && cities.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      final bool filtersApplied =
          _query.trim().isNotEmpty || _filter != ExploreCityFilter.all;
      if (state.status == HomeStatus.error && cities.isEmpty) {
        return Center(
          child: AppMessageState(
            icon: Icons.wifi_off_rounded,
            hue: context.tokigoColors.danger,
            title: l10n.exploreCitiesErrorTitle,
            body: l10n.exploreCitiesErrorBody,
            actionLabel: l10n.retry,
            onAction: () => ref.read(homeControllerProvider.notifier).load(),
          ),
        );
      }

      return Center(
        child: AppMessageState(
          icon: filtersApplied
              ? Icons.search_off_rounded
              : Icons.travel_explore_outlined,
          title: filtersApplied
              ? l10n.exploreNoMatchingCities
              : l10n.exploreNoCities,
          body: filtersApplied
              ? l10n.exploreNoMatchingCitiesBody
              : l10n.exploreNoCitiesBody,
          actionLabel: filtersApplied ? l10n.clearAll : null,
          onAction: filtersApplied
              ? () {
                  _searchController.clear();
                  setState(() {
                    _query = '';
                    _filter = ExploreCityFilter.all;
                  });
                }
              : null,
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 680 ? 3 : 2;
        return GridView.builder(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          itemCount: visibleCities.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.92,
          ),
          itemBuilder: (BuildContext context, int index) {
            final HomeItem city = visibleCities[index];
            return HomeDiscoveryStayCard(
              key: ValueKey<String>('explore-city-${city.id}'),
              item: city,
              aspectRatio: 0.92,
              fillSheet: false,
              onTap: () => context.push('/city', extra: city),
            );
          },
        );
      },
    );
  }

  String _filterLabel(AppLocalizations l10n, ExploreCityFilter filter) =>
      switch (filter) {
        ExploreCityFilter.all => l10n.exploreFilterAll,
        ExploreCityFilter.youth => l10n.exploreFilterYouth,
        ExploreCityFilter.families => l10n.exploreFilterFamilies,
        ExploreCityFilter.honeymoon => l10n.exploreFilterHoneymoon,
        ExploreCityFilter.beach => l10n.exploreFilterBeach,
        ExploreCityFilter.nature => l10n.exploreFilterNature,
        ExploreCityFilter.city => l10n.exploreFilterCity,
        ExploreCityFilter.shopping => l10n.exploreFilterShopping,
        ExploreCityFilter.snow => l10n.exploreFilterSnow,
      };
}
