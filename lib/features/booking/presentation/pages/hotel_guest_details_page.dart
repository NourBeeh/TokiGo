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

  /// The room (0-based) each guest belongs to. The provider books ONE primary
  /// guest per room, keyed by a 1-based `occupancyNumber`.
  final List<int> _roomOf = <int>[];

  /// The index of each room's primary guest (its first adult).
  final List<int> _primaryGuestIndex = <int>[];

  /// The booking holder's contact — Nuitee requires both an email and a phone.
  final TextEditingController _holderEmail = TextEditingController();
  final TextEditingController _holderPhone = TextEditingController();

  /// One contact email per room: the provider needs an email for the guest who
  /// holds each room, not just for the booking's lead traveller.
  final List<TextEditingController> _roomEmails = <TextEditingController>[];

  bool _validated = false;

  @override
  void initState() {
    super.initState();
    final occupancies = ref.read(hotelOccupanciesProvider);
    for (int r = 0; r < occupancies.length; r++) {
      final room = occupancies[r];
      _roomEmails.add(TextEditingController());
      _primaryGuestIndex.add(_controllers.length);
      for (int i = 0; i < room.adults; i++) {
        _controllers.add(TextEditingController());
        _isAdult.add(true);
        _roomOf.add(r);
      }
      for (int i = 0; i < room.childAges.length; i++) {
        _controllers.add(TextEditingController());
        _isAdult.add(false);
        _roomOf.add(r);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _holderEmail.dispose();
    _holderPhone.dispose();
    for (final c in _roomEmails) {
      c.dispose();
    }
    super.dispose();
  }

  static bool _isEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

  bool get _allValid =>
      _controllers.every((c) => c.text.trim().isNotEmpty) &&
      _isEmail(_holderEmail.text) &&
      _holderPhone.text.trim().isNotEmpty &&
      _roomEmails.every((c) => _isEmail(c.text));

  void _continue() {
    // Missing occupancy: there is no room context to collect guests for.
    // Block the submission instead of silently booking an unknown party.
    if (ref.read(hotelOccupanciesProvider).isEmpty) return;
    setState(() => _validated = true);
    if (!_allValid) return;

    final String holderEmail = _holderEmail.text.trim();
    final String holderPhone = _holderPhone.text.trim();
    final travelers = <Map<String, dynamic>>[];
    for (int i = 0; i < _controllers.length; i++) {
      final int room = _roomOf[i];
      final bool isPrimary = _primaryGuestIndex[room] == i;
      final String email = isPrimary ? _roomEmails[room].text.trim() : '';
      final parts = _controllers[i].text.trim().split(RegExp(r'\s+'));
      travelers.add(<String, dynamic>{
        'firstName': parts.isNotEmpty ? parts.first : '',
        'lastName': parts.length > 1 ? parts.sublist(1).join(' ') : '',
        'adult': _isAdult[i],
        // Every guest carries the room they sleep in, so the provider's
        // one-primary-guest-per-room contract can be satisfied exactly.
        'occupancyNumber': room + 1,
        if (i == 0) ...<String, dynamic>{
          // The lead traveller is the booking holder: their contact is what
          // the provider uses for the reservation.
          'email': holderEmail,
          'phone': holderPhone,
          'isHolder': true,
        } else if (email.isNotEmpty)
          'email': email,
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
                      body:
                          'Go back and choose your dates and guests to '
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
                    _FormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (
                            int r = 0;
                            r < occupancies.length;
                            r++
                          ) ...<Widget>[
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
                                        _controllers[cursor - 1].text
                                            .trim()
                                            .isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                            for (
                              int c = 0;
                              c < occupancies[r].childAges.length;
                              c++
                            )
                              _LabeledField(
                                label:
                                    'Child ${c + 1} (age '
                                    '${occupancies[r].childAges[c]}) name',
                                controller: _controllers[cursor++],
                                errorText:
                                    _validated &&
                                        _controllers[cursor - 1].text
                                            .trim()
                                            .isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _FormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Contact details',
                            style: typography.bodyLargeMedium.copyWith(
                              color: context.tokigoColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'We use these to confirm the booking with the '
                            'hotel.',
                            style: typography.caption.copyWith(
                              color: context.tokigoColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _LabeledField(
                            label: 'Booking email',
                            fieldKey: const Key('hotel-holder-email'),
                            controller: _holderEmail,
                            keyboardType: TextInputType.emailAddress,
                            errorText:
                                _validated && !_isEmail(_holderEmail.text)
                                ? 'Enter a valid email'
                                : null,
                          ),
                          _LabeledField(
                            label: 'Booking phone',
                            fieldKey: const Key('hotel-holder-phone'),
                            controller: _holderPhone,
                            keyboardType: TextInputType.phone,
                            errorText:
                                _validated && _holderPhone.text.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                          for (int r = 0; r < occupancies.length; r++)
                            _LabeledField(
                              label: 'Guest email for Room ${r + 1}',
                              fieldKey: Key('hotel-room-email-$r'),
                              controller: _roomEmails[r],
                              keyboardType: TextInputType.emailAddress,
                              errorText:
                                  _validated && !_isEmail(_roomEmails[r].text)
                                  ? 'Enter a valid email'
                                  : null,
                            ),
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

/// The funnel's one surface card: 16dp gutter, 16dp radius, outline border.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.tokigoColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.tokigoColors.outline),
      ),
      child: child,
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
    this.fieldKey,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? errorText;
  final Key? fieldKey;
  final TextInputType? keyboardType;

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
            key: fieldKey,
            controller: controller,
            keyboardType: keyboardType,
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
