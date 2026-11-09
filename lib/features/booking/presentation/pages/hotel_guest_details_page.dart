import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/features/search/application/controllers/hotel_search_controller.dart';
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';

class HotelGuestDetailsPage extends ConsumerStatefulWidget {
  const HotelGuestDetailsPage({super.key});

  @override
  ConsumerState<HotelGuestDetailsPage> createState() =>
      _HotelGuestDetailsPageState();
}

class _HotelGuestDetailsPageState extends ConsumerState<HotelGuestDetailsPage> {
  final List<TextEditingController> _controllers = <TextEditingController>[];
  final List<bool> _isAdult = <bool>[];
  bool _validated = false;

  @override
  void initState() {
    super.initState();
    final occupancies = ref.read(hotelOccupanciesProvider);
    for (final room in occupancies) {
      for (int i = 0; i < room.adults; i++) {
        _controllers.add(TextEditingController());
        _isAdult.add(true);
      }
      for (int i = 0; i < room.childAges.length; i++) {
        _controllers.add(TextEditingController());
        _isAdult.add(false);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _allValid =>
      _controllers.every((c) => c.text.trim().isNotEmpty);

  void _continue() {
    // Missing occupancy: there is no room context to collect guests for.
    // Block the submission instead of silently booking an unknown party.
    if (ref.read(hotelOccupanciesProvider).isEmpty) return;
    setState(() => _validated = true);
    if (!_allValid) return;
    final travelers = <Map<String, dynamic>>[];
    for (int i = 0; i < _controllers.length; i++) {
      final parts = _controllers[i].text.trim().split(RegExp(r'\s+'));
      travelers.add(<String, dynamic>{
        'firstName': parts.isNotEmpty ? parts.first : '',
        'lastName': parts.length > 1 ? parts.sublist(1).join(' ') : '',
        'adult': _isAdult[i],
      });
    }
    final occupancies = ref.read(hotelOccupanciesProvider);
    ref.read(hotelGuestTravelersProvider.notifier).state = travelers;
    ref.read(hotelGuestTravelersOwnerProvider.notifier).state =
        hotelGuestOwnershipKey(ref.read(selectedOfferProvider), occupancies);
    context.push('/booking/review');
  }

  @override
  Widget build(BuildContext context) {
    final occupancies = ref.watch(hotelOccupanciesProvider);
    final tc = context.tokigoColors;

    // No occupancy: the page was reached without a hotel search context. Show
    // an explicit state instead of a blank form with a dead Continue button.
    if (occupancies.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Guest details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.hotel_outlined, size: 44, color: tc.textTertiary),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No rooms selected',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Go back and choose your dates and guests to continue.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tc.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    int cursor = 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Guest details')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          for (int r = 0; r < occupancies.length; r++) ...<Widget>[
            Text('Room ${r + 1}: ${occupancies[r].adults} adults, ${occupancies[r].childAges.length} children'),
            const SizedBox(height: AppSpacing.sm),
            for (int a = 0; a < occupancies[r].adults; a++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: TextField(
                  controller: _controllers[cursor++],
                  decoration: InputDecoration(
                    labelText: 'Adult ${a + 1} name',
                    errorText: _validated && _controllers[cursor - 1].text.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                ),
              ),
            for (int c = 0; c < occupancies[r].childAges.length; c++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: TextField(
                  controller: _controllers[cursor++],
                  decoration: InputDecoration(
                    labelText: 'Child ${c + 1} (age ${occupancies[r].childAges[c]}) name',
                    errorText: _validated && _controllers[cursor - 1].text.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
          ElevatedButton(
            onPressed: _continue,
            child: const Text('Continue'),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
