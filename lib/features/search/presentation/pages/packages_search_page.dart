import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/domain/models/offers/travel_package_offer.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/features/search/presentation/widgets/search_scaffold.dart';
import 'package:tokigo/features/search/presentation/widgets/search_states_view.dart';
import 'package:tokigo/features/search/presentation/widgets/package_search_card.dart';

class PackagesSearchPage extends ConsumerStatefulWidget {
  const PackagesSearchPage({super.key});

  @override
  ConsumerState<PackagesSearchPage> createState() => _PackagesSearchPageState();
}

class _PackagesSearchPageState extends ConsumerState<PackagesSearchPage> {
  final _destCtrl = TextEditingController();
  final _departCtrl = TextEditingController();

  String _destinationLabel = '';
  DateTime _startDate = DateTime.now().add(const Duration(days: 7));
  int _tripDays = 5;

  bool _loading = false;
  bool _searched = false;
  int _lastTripDays = 5;
  List<HomeItem> _results = const [];

  // Mock data only this phase (Phase 19B) — no backend call.
  static final List<HomeItem> _mockPackages = [
    HomeItem(
      id: 'pkg-sharm-1',
      type: HomeCardType.package,
      title: 'Sharm El Sheikh · 5 days',
      subtitle: 'Flights + resort + transfers',
      price: 599,
      currency: 'USD',
      rating: 4.7,
      reviewCount: 132,
      highlights: ['All inclusive', 'Airport transfer'],
      imageUrl: 'assets/images/placeholder_package.png',
    ),
    HomeItem(
      id: 'pkg-luxor-1',
      type: HomeCardType.package,
      title: 'Luxor & Aswan cruise · 4 nights',
      subtitle: 'Nile cruise with guided tours',
      price: 749,
      currency: 'USD',
      rating: 4.8,
      reviewCount: 87,
      highlights: ['Guided temples', 'Full board'],
      imageUrl: 'assets/images/placeholder_package.png',
    ),
    HomeItem(
      id: 'pkg-hurghada-1',
      type: HomeCardType.package,
      title: 'Hurghada getaway · 4 days',
      subtitle: 'Beach resort + snorkeling trips',
      price: 459,
      currency: 'USD',
      rating: 4.5,
      reviewCount: 118,
      highlights: ['Reef snorkeling', 'All inclusive'],
      imageUrl: 'assets/images/placeholder_package.png',
    ),
    HomeItem(
      id: 'pkg-siwa-1',
      type: HomeCardType.package,
      title: 'Siwa Oasis safari · 3 days',
      subtitle: 'Desert springs & salt lakes',
      price: 329,
      currency: 'USD',
      rating: 4.6,
      reviewCount: 64,
      highlights: ['4x4 desert safari', 'Eco lodge stay'],
      imageUrl: 'assets/images/placeholder_package.png',
    ),
    HomeItem(
      id: 'pkg-whitedesert-1',
      type: HomeCardType.package,
      title: 'White Desert camping · 2 nights',
      subtitle: 'Crystal formations under the stars',
      price: 289,
      currency: 'USD',
      rating: 4.8,
      reviewCount: 52,
      highlights: ['Bedouin dinner', 'Stargazing camp'],
      imageUrl: 'assets/images/placeholder_package.png',
    ),
    HomeItem(
      id: 'pkg-abusimbel-1',
      type: HomeCardType.package,
      title: 'Aswan & Abu Simbel · 3 days',
      subtitle: 'Temples, felucca sailing & Nubian village',
      price: 419,
      currency: 'USD',
      rating: 4.7,
      reviewCount: 76,
      highlights: ['Abu Simbel entry', 'Felucca sunset sail'],
      imageUrl: 'assets/images/placeholder_package.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _departCtrl.text = DateFormat('EEE, MMM d').format(_startDate);
  }

  @override
  void dispose() {
    _destCtrl.dispose();
    _departCtrl.dispose();
    super.dispose();
  }

  void _search(String destination, int tripDays) {
    setState(() {
      _loading = true;
      _searched = true;
      _destinationLabel = destination.trim();
      _lastTripDays = tripDays;
    });
    // Local filtering only this phase — simulate the async search rhythm so
    // the skeleton state is visible, then swap in the results.
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      var results = List.of(_mockPackages);
      final query = destination.trim().toLowerCase();
      if (query.isNotEmpty) {
        results = results.where((p) =>
            p.title.toLowerCase().contains(query) ||
            (p.subtitle ?? '').toLowerCase().contains(query)).toList();
      }
      if (tripDays <= 2) {
        results = results.where((p) => (p.price ?? 0) < 500).toList();
      }
      setState(() {
        _results = results;
        _loading = false;
      });
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() {
        _startDate = d;
        _departCtrl.text = DateFormat('EEE, MMM d').format(_startDate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SearchScaffold(
      hue: AppColors.packageHue,
      title: 'Tour packages',
      subtitle: 'Curated multi-day programs',
      collapsedTitle: _destinationLabel.isEmpty
          ? 'Tour packages'
          : 'Packages · $_destinationLabel',
      form: _buildForm(),
      body: _buildResults(),
    );
  }

  // ── Form ────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchFieldInput(
          icon: Icons.location_on_outlined,
          hint: 'Where do you want to go?',
          controller: _destCtrl,
          keyboardType: TextInputType.text,
          suffix: _destCtrl.text.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() {
                    _destCtrl.clear();
                    _destinationLabel = '';
                  }),
                  child: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.textTertiary),
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: SearchFieldInput(
                icon: Icons.calendar_today_outlined,
                hint: 'Departure',
                controller: _departCtrl,
                readOnly: true,
                onTap: _pickDate,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildTripLengthRow(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SearchSubmitButton(
          label: 'Search packages',
          onPressed: () => _search(_destCtrl.text, _tripDays),
          hue: AppColors.packageHue,
        ),
      ],
    );
  }

  Widget _buildTripLengthRow() {
    final typography = AppTypography.forLight();
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.timelapse_rounded, size: 20, color: AppColors.brand),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '$_tripDays days',
              style: typography.bodyLarge.copyWith(color: AppColors.textPrimary),
            ),
          ),
          _stepperButton(Icons.remove_rounded, () {
            if (_tripDays > 2) setState(() => _tripDays--);
          }),
          const SizedBox(width: AppSpacing.md),
          _stepperButton(Icons.add_rounded, () {
            if (_tripDays < 21) setState(() => _tripDays++);
          }),
        ],
      ),
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.brandContainer,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Icon(icon, size: 18, color: AppColors.brand),
      ),
    );
  }

  // ── Results ─────────────────────────────────────────────────────────────
  Widget _buildResults() {
    if (_loading) {
      return const SearchStatesView.loading(
        skeleton: Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: PackageSearchCard.loading(),
        ),
      );
    }
    if (!_searched) {
      return const SearchStatesView.idle(
        icon: Icons.tour_outlined,
        title: 'Discover curated tours',
        body: 'Pick a destination and travel length',
      );
    }
    if (_results.isEmpty) {
      return SearchStatesView.empty(
        icon: Icons.search_off_rounded,
        title: 'No packages found',
        body: 'Try a different destination or trip length',
        actionLabel: 'Reset search',
        onAction: () => _search('', _lastTripDays),
      );
    }
    return Column(
      children: [
        for (final item in _results)
          PackageSearchCard(
            offer: _convertToTravelPackageOffer(item),
            onTap: () => context.push(
              '/offer-details',
              extra: _convertToTravelPackageOffer(item),
            ),
          ),
      ],
    );
  }

  TravelPackageOffer _convertToTravelPackageOffer(HomeItem item) {
    final metadata = item.metadata;
    return TravelPackageOffer(
      id: item.id,
      providerId: metadata['providerId']?.toString() ?? '',
      providerName: metadata['providerName']?.toString() ?? '',
      title: item.title,
      subtitle: item.subtitle,
      description: item.description,
      imageUrl: item.imageUrl,
      price: item.price ?? 0,
      currency: item.currency ?? 'USD',
      availability: item.metadata['availability'] as bool?,
      validUntil: item.metadata['validUntil'] is DateTime
          ? item.metadata['validUntil'] as DateTime
          : null,
      metadata: Map<String, dynamic>.from(metadata),
      rating: item.rating,
      reviewCount: item.reviewCount,
      destination: metadata['destination']?.toString() ?? item.subtitle ?? '',
      durationDays: metadata['durationDays'] is int
          ? metadata['durationDays'] as int
          : int.tryParse(metadata['durationDays']?.toString() ?? '') ?? 0,
      inclusions: (metadata['inclusions'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
