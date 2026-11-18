import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/core/widgets/sticky_cta_bar.dart';
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
    final typography = _type(context);

    // No occupancy: the page was reached without a hotel search context. Show
    // an explicit state instead of a blank form with a dead Continue button.
    if (occupancies.isEmpty) {
      return Scaffold(
        backgroundColor: context.tokigoColors.background,
        body: SafeArea(
          child: AiEntranceAnimation(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const AppPageHeader(
                  subtitle: 'Guest details',
                  backFallbackLocation: '/booking/review',
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: AppMessageState(
                      icon: Icons.hotel_outlined,
                      title: 'No rooms selected',
                      body: 'Go back and choose your dates and guests to '
                          'continue.',
                      actionLabel: 'Go back',
                      onAction: () => context.pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    int cursor = 0;
    return Scaffold(
      backgroundColor: context.tokigoColors.background,
      body: SafeArea(
        child: AiEntranceAnimation(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // The funnel's one header: the page's own description beside the
              // back control, instead of a raw Material app bar.
              const AppPageHeader(
                subtitle: 'Guest details',
                backFallbackLocation: '/booking/review',
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    _barClearance(context),
                  ),
                  children: <Widget>[
                    // One surface card, one gutter, one corner radius — the
                    // same recipe as the passenger form.
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: context.tokigoColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: context.tokigoColors.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (int r = 0; r < occupancies.length; r++) ...<Widget>[
                            if (r > 0) const SizedBox(height: AppSpacing.lg),
                            Text(
                              'Room ${r + 1}: ${occupancies[r].adults} adults, '
                              '${occupancies[r].childAges.length} children',
                              style: typography.bodyLargeMedium.copyWith(
                                color: context.tokigoColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            for (int a = 0; a < occupancies[r].adults; a++)
                              _LabeledField(
                                label: 'Adult ${a + 1} name',
                                controller: _controllers[cursor++],
                                errorText:
                                    _validated &&
                                        _controllers[cursor - 1]
                                            .text
                                            .trim()
                                            .isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                            for (int c = 0;
                                c < occupancies[r].childAges.length;
                                c++)
                              _LabeledField(
                                label:
                                    'Child ${c + 1} (age '
                                    '${occupancies[r].childAges[c]}) name',
                                controller: _controllers[cursor++],
                                errorText:
                                    _validated &&
                                        _controllers[cursor - 1]
                                            .text
                                            .trim()
                                            .isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: StickyCtaBar(
        child: AppButton(label: 'Continue', onPressed: _continue),
      ),
    );
  }
}

/// The funnel's form recipe: a small external label above the field, on the
/// card's 16dp gutter, with a 12dp rhythm between fields.
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: _type(context).label),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: controller,
            decoration: InputDecoration(errorText: errorText),
          ),
        ],
      ),
    );
  }
}

/// Space the pinned bar occupies: its 12dp top/bottom padding, the 52dp CTA,
/// and the system navigation inset.
double _barClearance(BuildContext context) =>
    AppSpacing.md * 2 + 52 + MediaQuery.viewPaddingOf(context).bottom;

/// The type scale for the active brightness — the light and dark palettes
/// carry different text colours, so the scale is resolved per surface.
AppTypography _type(BuildContext context) =>
    context.isDark ? AppTypography.forDark() : AppTypography.forLight();
