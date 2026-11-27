import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/domain/models/search/hotel_room_occupancy.dart';
import 'package:tokigo/core/domain/models/search/hotel_search_params.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/localized_date.dart';
import 'package:tokigo/core/widgets/compact_stepper_row.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/core/widgets/pressable.dart';
import 'package:tokigo/core/widgets/section_header.dart';
import 'package:tokigo/features/home/domain/promotional_stay.dart';
import 'package:tokigo/features/home/presentation/open_stay_map.dart';
import 'package:tokigo/features/home/presentation/widgets/cached_hotel_image.dart';
import 'package:tokigo/features/search/application/controllers/hotel_search_controller.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';
import 'package:tokigo/features/search/application/providers/hotel_car_providers.dart';
import 'package:tokigo/features/search/presentation/widgets/hotel_overlap_card.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Live-search controller for the Nearby hotel details page.
///
/// Deliberately separate from the search page's controller: opening a
/// promotional card must not disturb an in-progress city search.
final nearbyHotelSearchControllerProvider =
    StateNotifierProvider<HotelSearchController, HotelSearchState>((ref) {
      return HotelSearchController(
        ref.watch(hotelRepositoryProvider),
        ref.watch(offlineCacheProvider),
      );
    });

/// Hotel details for a promotional Nearby Stays card (R9).
///
/// The promotional price is shown only as a discovery caption. The page never
/// auto-runs a live search: the traveller picks dates and occupancy, then
/// explicitly asks for availability. Live results are real provider offers
/// and flow into the existing offer-details → revalidation → booking path.
class NearbyHotelDetailsPage extends ConsumerStatefulWidget {
  const NearbyHotelDetailsPage({super.key, required this.stay});

  final PromotionalStay stay;

  @override
  ConsumerState<NearbyHotelDetailsPage> createState() =>
      _NearbyHotelDetailsPageState();
}

class _NearbyHotelDetailsPageState
    extends ConsumerState<NearbyHotelDetailsPage> {
  late DateTime _checkIn;
  late DateTime _checkOut;
  int _adults = 2;
  int _rooms = 1;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _checkIn = now.add(const Duration(days: 7));
    _checkOut = now.add(const Duration(days: 10));
  }

  Future<void> _pickCheckIn() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _checkIn,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _checkIn = picked;
      if (!_checkOut.isAfter(_checkIn)) {
        _checkOut = _checkIn.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _pickCheckOut() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _checkOut,
      firstDate: _checkIn.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _checkOut = picked);
  }

  void _search() {
    final HotelSearchParams params = HotelSearchParams(
      destination: widget.stay.city,
      checkIn: _checkIn,
      checkOut: _checkOut,
      rooms: _rooms,
      adults: _adults,
      // One occupancy per room: the picked adult total is spread across the
      // rooms so the search party matches the one on screen.
      occupancies: distributeAdultsAcrossRooms(adults: _adults, rooms: _rooms),
      countryCode: widget.stay.country,
      languageCode: AppLocalizations.of(context)?.localeName == 'ar'
          ? 'ar'
          : 'en',
    );
    ref.read(nearbyHotelSearchControllerProvider.notifier).search(params);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final PromotionalStay stay = widget.stay;
    final searchState = ref.watch(nearbyHotelSearchControllerProvider);
    final List<HotelOffer> liveResults = <HotelOffer>[
      for (final HotelOffer offer in searchState.results)
        if (offer.metadata['providerHotelId']?.toString() == stay.hotelId)
          offer,
    ];

    final bool showLiveResults =
        searchState.status == HotelSearchStatus.success &&
        liveResults.isNotEmpty;
    final bool showNoLiveOffer =
        searchState.status == HotelSearchStatus.success && liveResults.isEmpty;
    final bool showSearchError = searchState.status == HotelSearchStatus.error;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: AppPageHeader(
                subtitle: <String>[
                  stay.city,
                  stay.country,
                ].where((String part) => part.isNotEmpty).join(', '),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: (stay.image == null || stay.image!.isEmpty)
                      ? Container(
                          height: 200,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: const Icon(Icons.house_rounded, size: 40),
                        )
                      : CachedHotelImage(
                          url: stay.image!,
                          width: double.infinity,
                          height: 200,
                        ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (stay.hasRealReviews)
                      Text(
                        '${stay.rating!.toStringAsFixed(1)}★ · ${l10n.nearbyHotelReviews(stay.reviewCount.toString())}',
                        style: AppTypography.forLight().bodyMedium,
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.nearbyHotelDistanceFromYou(
                        stay.distanceKm.toStringAsFixed(1),
                      ),
                      style: AppTypography.forLight().body,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // The promotional price is a discovery caption only. It is
                    // never presented as a live booking offer.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${l10n.unitNight}: ${stay.promotionalMinimumPrice.toStringAsFixed(0)} ${stay.currency}',
                            style: AppTypography.forLight().titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            l10n.nearbyHotelPromotionalCaption,
                            style: AppTypography.forLight().caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SectionHeader(title: l10n.nearbyHotelSelectDates),
                    _DateRow(
                      label: l10n.nearbyHotelCheckIn,
                      value: localizedMediumDate(context, _checkIn),
                      onTap: _pickCheckIn,
                    ),
                    _DateRow(
                      label: l10n.nearbyHotelCheckOut,
                      value: localizedMediumDate(context, _checkOut),
                      onTap: _pickCheckOut,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CompactStepperRow(
                      label: l10n.nearbyHotelAdults,
                      value: _adults,
                      onDecrement: _adults > 1
                          ? () => setState(() => _adults--)
                          : null,
                      onIncrement: _adults < 8
                          ? () => setState(() => _adults++)
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    CompactStepperRow(
                      label: l10n.nearbyHotelRooms,
                      value: _rooms,
                      onDecrement: _rooms > 1
                          ? () => setState(() => _rooms--)
                          : null,
                      onIncrement: _rooms < 4
                          ? () => setState(() => _rooms++)
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            searchState.status == HotelSearchStatus.loading
                            ? null
                            : _search,
                        child: Text(l10n.nearbyHotelSearchAvailability),
                      ),
                    ),
                    if (searchState.status == HotelSearchStatus.loading)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.md),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
            if (showLiveResults) ...<Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: SectionHeader(title: l10n.nearbyHotelLiveResults),
                ),
              ),
              SliverList.builder(
                itemCount: liveResults.length,
                itemBuilder: (BuildContext context, int index) =>
                    HotelOverlapCard(
                      offer: liveResults[index],
                      onTap: () => context.push(
                        '/offer-details',
                        extra: liveResults[index],
                      ),
                    ),
              ),
            ],
            if (showNoLiveOffer)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                  child: Text(l10n.nearbyHotelNoLiveOffer),
                ),
              ),
            if (showSearchError)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l10n.homeNearbyErrorTitle),
                      const SizedBox(height: AppSpacing.xs),
                      Text(l10n.homeNearbyErrorBody),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: AppSpacing.md,
                  bottom: AppSpacing.xl,
                ),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () => openStayInMaps(
                      name: stay.hotelName,
                      location: <String>[
                        stay.city,
                        stay.country,
                      ].where((String part) => part.isNotEmpty).join(', '),
                      latitude: stay.latitude,
                      longitude: stay.longitude,
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: Text(l10n.hotelOpenLocationInMaps),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable.wrap(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text(value),
        trailing: const Icon(Icons.calendar_month_outlined),
        onTap: onTap,
      ),
    );
  }
}
