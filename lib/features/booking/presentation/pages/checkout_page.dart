import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/search/hotel_room_occupancy.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/core/widgets/pressable.dart';
import 'package:tokigo/core/widgets/step_progress.dart';
import 'package:tokigo/core/widgets/sticky_cta_bar.dart';
import 'package:tokigo/features/bag/domain/trip.dart';
import 'package:tokigo/features/booking/application/booking_providers.dart';
import 'package:tokigo/features/booking/application/booking_state.dart';
import 'package:tokigo/features/booking/application/providers/checkout_flow_providers.dart';
import 'package:tokigo/features/search/application/controllers/hotel_search_controller.dart';
import 'package:tokigo/features/booking/application/services/checkout_payment_service.dart';
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Step 4 of the booking funnel — payment.
///
/// **OWNER DECISION (2026-10-19): real booking only.** v1 shipped mock
/// processing: it invented a booking id (`booking-<timestamp>`) to charge
/// against, invented a 14% "taxes & fees" line on top of the provider price,
/// and declared the trip confirmed whatever the backend said. Now the payment
/// and the confirmation both act on the REAL prepared booking created by the
/// booking review (real booking id, real provider price, real currency), the
/// breakdown shows only what the provider quoted, and the funnel only reaches
/// the confirmation page when the backend actually confirmed the booking.
class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  PaymentMethod _method = PaymentMethod.card;

  /// The last provider message, shown as a strip above the bar (doc 21 §6).
  String? _failure;
  bool _processing = false;
  final _cardNumber = TextEditingController();
  final _cardName = TextEditingController();
  final _expiry = TextEditingController();
  final _cvc = TextEditingController();
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _method = ref.read(checkoutPaymentMethodProvider);
  }

  @override
  void dispose() {
    _cardNumber.dispose();
    _cardName.dispose();
    _expiry.dispose();
    _cvc.dispose();
    super.dispose();
  }

  bool get _cardValid {
    if (_method != PaymentMethod.card) return true;
    final digits = _cardNumber.text.replaceAll(' ', '');
    return digits.length >= 15 &&
        _cardName.text.trim().isNotEmpty &&
        _expiry.text.trim().isNotEmpty &&
        _cvc.text.trim().length >= 3;
  }

  /// Validates the hotel guest data against the selected offer + occupancy.
  ///
  /// Returns a localized error when the booking is a hotel and the guests are
  /// missing, stale, or do not match the occupancy. Returns null for flights
  /// (they use `checkoutTravelersProvider`) and for valid hotel data.
  String? _hotelGuestError() {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final SelectedOffer? selectedOffer = ref.read(selectedOfferProvider);
    if (selectedOffer?.offerType != 'hotel') return null;

    final List<HotelRoomOccupancy> occupancies = ref.read(
      hotelOccupanciesProvider,
    );
    final String expectedKey = hotelGuestOwnershipKey(
      selectedOffer,
      occupancies,
    );
    if (expectedKey.isEmpty ||
        ref.read(hotelGuestTravelersOwnerProvider) != expectedKey) {
      return l10n.hotelGuestInvalidBody;
    }

    final List<Map<String, dynamic>> guests = ref.read(
      hotelGuestTravelersProvider,
    );
    if (guests.isEmpty) return l10n.hotelGuestInvalidBody;

    final int expectedAdults = occupancies.fold<int>(
      0,
      (int sum, HotelRoomOccupancy room) => sum + room.adults,
    );
    final int expectedChildren = occupancies.fold<int>(
      0,
      (int sum, HotelRoomOccupancy room) => sum + room.childAges.length,
    );
    int adults = 0;
    int children = 0;
    for (final Map<String, dynamic> guest in guests) {
      final String firstName = (guest['firstName'] as String?)?.trim() ?? '';
      final String lastName = (guest['lastName'] as String?)?.trim() ?? '';
      if (firstName.isEmpty || lastName.isEmpty) {
        return l10n.hotelGuestInvalidBody;
      }
      if (guest['adult'] == true) {
        adults++;
      } else {
        children++;
      }
    }
    if (adults != expectedAdults || children != expectedChildren) {
      return l10n.hotelGuestInvalidBody;
    }
    return null;
  }

  void _fail(String message) {
    setState(() => _failure = message);
  }

  Future<void> _pay() async {
    if (_failure != null) setState(() => _failure = null);
    final l10n = AppLocalizations.of(context)!;
    if (!_cardValid) {
      setState(() => _showErrors = true);
      return;
    }

    // Hotel bookings: the guest data must belong to THIS offer + occupancy.
    // Block before any charge or confirmation — never fall back to flight
    // travellers or the sandbox default for a hotel.
    final String? hotelGuestError = _hotelGuestError();
    if (hotelGuestError != null) {
      _fail(hotelGuestError);
      return;
    }
    // Capture the travelers once, after validation, so the exact validated
    // data is what reaches the controller.
    final List<Map<String, dynamic>> travelers = _travelers();

    // Real booking only: both the charge and the confirmation act on the
    // prepared booking the backend created for this offer. Without one there
    // is nothing to pay for — we never invent a booking id.
    final booking = ref.read(bookingControllerProvider);
    final record = booking.record;
    if (record == null) {
      _say(l10n.checkoutNoBookingBody);
      return;
    }

    ref.read(checkoutPaymentMethodProvider.notifier).state = _method;
    setState(() => _processing = true);

    // Real backend payment orchestration (spec point 31): intent -> confirm
    // through the market-routed gateway; 3DS/pending and declined states
    // surface exactly like production flows.
    final addOnsTotal = ref
        .read(checkoutAddOnsProvider)
        .fold<double>(0, (s, a) => s + a.total);
    // The provider's authoritative price is the only price that exists; the
    // backend sends no base/tax split, so no split is shown.
    final total = record.authoritativePrice + addOnsTotal;
    final currency = record.currency.isEmpty
        ? ref.read(checkoutCurrencyProvider)
        : record.currency;

    final result = await ref
        .read(checkoutPaymentServiceProvider)
        .pay(
          // The real prepared booking, not a client invention.
          bookingId: record.bookingId,
          amount: total,
          currency: currency,
          market: 'EG',
          idempotencyKey: 'pay-${record.bookingId}-${_method.name}',
          method: switch (_method) {
            PaymentMethod.wallet => 'wallet',
            // Not offered by the UI (the gateway has no such method); mapped
            // to the wallet route only so the enum stays exhaustive.
            PaymentMethod.payAtHotel => 'wallet',
            PaymentMethod.card =>
              _cardNumber.text.startsWith('4') ? 'card' : 'card_3ds',
          },
        );

    if (!mounted) return;

    switch (result.outcome) {
      case PaymentOutcome.succeeded:
        // Payment really completed — now let the backend confirm the booking.
        // The confirmation page reads that real record; the funnel never
        // reaches it on a booking that was not confirmed.
        if (ref.read(bookingControllerProvider).phase ==
            BookingPhase.confirmed) {
          setState(() => _processing = false);
          context.go('/booking/review/confirmation');
          return;
        }
        await ref
            .read(bookingControllerProvider.notifier)
            .confirm(
              travelers: travelers,
              // The booked offer, so My Trips can name the trip it just made.
              item: _bookedItem(ref),
            );
        if (!mounted) return;
        setState(() => _processing = false);
        if (ref.read(bookingControllerProvider).phase ==
            BookingPhase.confirmed) {
          context.go('/booking/review/confirmation');
        } else {
          _fail(l10n.bookingConfirmFailedBody);
        }
      case PaymentOutcome.pending3ds:
        // The bank has not approved yet, so the booking is NOT confirmed —
        // saying otherwise would be a lie.
        setState(() => _processing = false);
        _fail(l10n.paymentPendingBody);
      case PaymentOutcome.failed:
        setState(() => _processing = false);
        _fail(l10n.paymentFailedBody);
      case PaymentOutcome.unavailable:
        setState(() => _processing = false);
        _fail(l10n.paymentUnavailableBody);
    }
  }

  /// The travellers the customer actually entered, shaped for the backend
  /// (contact details go on the lead traveller). No defaults, no placeholders.
  List<Map<String, dynamic>> _travelers() {
    final selectedOffer = ref.read(selectedOfferProvider);
    if (selectedOffer?.offerType == 'hotel') {
      final hotelTravelers = ref.read(hotelGuestTravelersProvider);
      final owner = ref.read(hotelGuestTravelersOwnerProvider);
      final expected = hotelGuestOwnershipKey(
        selectedOffer,
        ref.read(hotelOccupanciesProvider),
      );
      // Only the guests collected for THIS offer + occupancy are valid. A
      // missing or mismatched key means the payload is stale, so it is
      // ignored rather than silently booked.
      if (hotelTravelers.isNotEmpty &&
          expected.isNotEmpty &&
          owner == expected) {
        final contact = ref.read(checkoutContactProvider);
        return <Map<String, dynamic>>[
          for (int i = 0; i < hotelTravelers.length; i++)
            <String, dynamic>{
              'firstName': hotelTravelers[i]['firstName'],
              'lastName': hotelTravelers[i]['lastName'],
              'adult': hotelTravelers[i]['adult'] == true,
              if (i == 0 && contact.email.isNotEmpty) 'email': contact.email,
            },
        ];
      }
    }
    final travelers = ref.read(checkoutTravelersProvider);
    final contact = ref.read(checkoutContactProvider);
    return <Map<String, dynamic>>[
      for (int i = 0; i < travelers.length; i++)
        <String, dynamic>{
          'firstName': travelers[i].firstName,
          'lastName': travelers[i].lastName,
          if (travelers[i].dob != null && travelers[i].dob!.isNotEmpty)
            'dateOfBirth': travelers[i].dob,
          // The passenger form collects these; dropping them here would lose
          // data the provider needs (gender / born_on, document details).
          if (travelers[i].gender.isNotEmpty) 'gender': travelers[i].gender,
          if (travelers[i].nationality.isNotEmpty)
            'nationality': travelers[i].nationality,
          if (travelers[i].documentType.isNotEmpty)
            'documentType': travelers[i].documentType,
          if (travelers[i].documentNumber.isNotEmpty)
            'documentNumber': travelers[i].documentNumber,
          if (travelers[i].documentIssueCountry.isNotEmpty)
            'documentIssueCountry': travelers[i].documentIssueCountry,
          if (travelers[i].documentExpiry.isNotEmpty)
            'documentExpiry': travelers[i].documentExpiry,
          // The lead contact stays available for providers that only accept a
          // single contact (hotels, Nuitee flights).
          if (i == 0 && contact.email.isNotEmpty) 'email': contact.email,
          if (i == 0 && contact.phone.isNotEmpty) 'phone': contact.phone,
          // P3-D5: Duffel requires a title, an email and a phone for EVERY
          // passenger. These are per-passenger values — the lead contact is
          // never copied onto another traveller, and a passenger's own value
          // wins when both are present.
          if (travelers[i].title.isNotEmpty) 'title': travelers[i].title,
          if (travelers[i].email.isNotEmpty) 'email': travelers[i].email,
          if (travelers[i].phone.isNotEmpty) 'phone': travelers[i].phone,
          // The calling code is a separate LiteAPI field; it travels on the
          // lead traveller (the booking's primary contact).
          if (i == 0 && contact.phoneCountryCode.isNotEmpty)
            'phoneCountryCode': contact.phoneCountryCode,
          'passengerType': travelers[i].passengerType,
          if (travelers[i].accompanyingAdultIndex != null)
            'accompanyingAdultIndex': travelers[i].accompanyingAdultIndex,
        },
    ];
  }

  /// The offer the funnel is booking, reduced to the facts My Trips shows.
  /// Null when no offer was carried — the trip then states fewer facts.
  TripItem? _bookedItem(WidgetRef ref) {
    final offer = ref.read(selectedOfferProvider);
    if (offer == null) return null;
    return TripItem(
      title: offer.title,
      subtitle: offer.subtitle,
      imageUrl: offer.imageUrl,
      startsAt: offer.startsAt,
      endsAt: offer.endsAt,
    );
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final typography = _type(context);
    final l10n = AppLocalizations.of(context)!;
    final record = ref.watch(bookingControllerProvider).record;

    // No prepared booking → nothing to pay for. Saying so (with a way back) is
    // the honest version of what v1 faked with a generated booking id.
    if (record == null) {
      return Scaffold(
        backgroundColor: context.tokigoColors.background,
        body: SafeArea(
          bottom: false,
          child: AiEntranceAnimation(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppPageHeader(
                  subtitle: l10n.paymentSubtitle,
                  backFallbackLocation: '/booking/review',
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: AppMessageState(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.checkoutNoBookingTitle,
                      body: l10n.checkoutNoBookingBody,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final addOns = ref.watch(checkoutAddOnsProvider);
    final addOnsTotal = addOns.fold<double>(0, (s, a) => s + a.total);
    final currency = record.currency.isEmpty
        ? ref.watch(checkoutCurrencyProvider)
        : record.currency;
    // Provider price + real add-ons. No invented taxes or fees.
    final total = record.authoritativePrice + addOnsTotal;

    return Scaffold(
      backgroundColor: context.tokigoColors.background,
      body: SafeArea(
        bottom: false,
        // The scrim is a sibling of the whole column, not just the list: a
        // charge in flight dims the header too, so no part of the surface
        // reads as still live.
        child: Stack(
          children: <Widget>[
            AiEntranceAnimation(
              child: AbsorbPointer(
                absorbing: _processing,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppPageHeader(
                      subtitle: l10n.paymentSubtitle,
                      // Doc 21 §1 — the funnel is 4 steps; checkout is the last.
                      steps: const StepProgress(current: 3, total: 4),
                      backFallbackLocation: '/booking/review',
                      // Leaving mid-charge is blocked (the body is inert too);
                      // the control keeps its place and mutes instead of
                      // vanishing.
                      backEnabled: !_processing,
                    ),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          _barClearance(context) +
                              (_failure != null ? _failureStripReserve : 0),
                        ),
                        children: <Widget>[
                          Text(
                            l10n.checkoutPaymentMethod,
                            style: typography.bodyLargeMedium.copyWith(
                              color: context.tokigoColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _MethodTile(
                            icon: Icons.credit_card_rounded,
                            label: l10n.checkoutCard,
                            selected: _method == PaymentMethod.card,
                            onTap: () =>
                                setState(() => _method = PaymentMethod.card),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _MethodTile(
                            icon: Icons.account_balance_wallet_rounded,
                            label: l10n.checkoutWallet,
                            selected: _method == PaymentMethod.wallet,
                            onTap: () =>
                                setState(() => _method = PaymentMethod.wallet),
                          ),
                          // Doc 21 §11.1 / decision D4 — card + wallet are the
                          // methods the payment gateway really accepts. There
                          // is no pay-at-property method, so offering one
                          // would promise a charge the backend cannot take.
                          if (_method == PaymentMethod.card) ...<Widget>[
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              l10n.checkoutCardDetails,
                              style: typography.bodyLargeMedium.copyWith(
                                color: context.tokigoColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _CardFields(
                              cardNumber: _cardNumber,
                              cardName: _cardName,
                              expiry: _expiry,
                              cvc: _cvc,
                              showErrors: _showErrors,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            l10n.checkoutPriceBreakdown,
                            style: typography.bodyLargeMedium.copyWith(
                              color: context.tokigoColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _PriceBreakdownCard(
                            providerPrice: record.authoritativePrice,
                            addOnsTotal: addOnsTotal,
                            total: total,
                            currency: currency,
                            addOns: addOns,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_processing)
              Positioned.fill(
                child: ColoredBox(
                  color: context.tokigoColors.background.withValues(alpha: 0.7),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          l10n.checkoutProcessing,
                          style: typography.bodyLargeMedium.copyWith(
                            color: context.tokigoColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomSheet: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_failure != null) _FailureStrip(message: _failure!),
          StickyCtaBar(
            child: Row(
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      l10n.total,
                      style: typography.caption.copyWith(
                        color: context.tokigoColors.textSecondary,
                      ),
                    ),
                    Text(
                      '$currency ${total.toStringAsFixed(2)}',
                      maxLines: 1,
                      style: typography.titleMedium.copyWith(
                        color: context.tokigoColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: AppButton(
                    // The amount is always in the label (doc 21 §6).
                    label: l10n.payAmount(
                      '$currency ${total.toStringAsFixed(2)}',
                    ),
                    leadingIcon: Icons.lock_rounded,
                    onPressed: _processing ? null : _pay,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = _type(context);
    return Pressable.wrap(
      child: Material(
        color: context.tokigoColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            // A payment row is a 48dp control, whatever the glyph inside it.
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minimumTapTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: selected
                    ? context.tokigoColors.brand
                    : context.tokigoColors.outline,
                width: selected ? 1.5 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 22,
                  color: context.tokigoColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: typography.bodyMedium.copyWith(
                      color: context.tokigoColors.textPrimary,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? context.tokigoColors.brand
                          : context.tokigoColors.outline,
                      width: 2,
                    ),
                    color: selected
                        ? context.tokigoColors.brand
                        : Colors.transparent,
                  ),
                  // The tick sits on the brand fill, so its ink is the
                  // palette's on-brand — white-on-brand is 1.09:1 in the dark
                  // canvas and unreadable.
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: context.tokigoColors.onBrand,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardFields extends StatelessWidget {
  const _CardFields({
    required this.cardNumber,
    required this.cardName,
    required this.expiry,
    required this.cvc,
    required this.showErrors,
  });

  final TextEditingController cardNumber;
  final TextEditingController cardName;
  final TextEditingController expiry;
  final TextEditingController cvc;
  final bool showErrors;

  @override
  Widget build(BuildContext context) {
    final digits = cardNumber.text.replaceAll(' ', '');
    return Column(
      children: <Widget>[
        _LabeledField(
          label: 'Card number',
          controller: cardNumber,
          keyboardType: TextInputType.number,
          hintText: '4242 4242 4242 4242',
          errorText: showErrors && digits.length < 15
              ? 'Enter a valid card number'
              : null,
        ),
        _LabeledField(
          label: 'Name on card',
          controller: cardName,
          errorText: showErrors && cardName.text.trim().isEmpty
              ? 'Required'
              : null,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _LabeledField(
                label: 'Expiry',
                controller: expiry,
                keyboardType: TextInputType.number,
                hintText: 'MM/YY',
                errorText: showErrors && expiry.text.trim().isEmpty
                    ? 'Required'
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _LabeledField(
                label: 'CVC',
                controller: cvc,
                keyboardType: TextInputType.number,
                obscureText: true,
                hintText: '123',
                errorText: showErrors && cvc.text.trim().length < 3
                    ? '3 digits'
                    : null,
              ),
            ),
          ],
        ),
      ],
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
    this.keyboardType,
    this.hintText,
    this.obscureText = false,
  });

  final String label;
  final TextEditingController controller;
  final String? errorText;
  final TextInputType? keyboardType;
  final String? hintText;
  final bool obscureText;

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
            keyboardType: keyboardType,
            obscureText: obscureText,
            decoration: InputDecoration(errorText: errorText, hintText: hintText),
          ),
        ],
      ),
    );
  }
}

class _PriceBreakdownCard extends StatelessWidget {
  const _PriceBreakdownCard({
    required this.providerPrice,
    required this.addOnsTotal,
    required this.total,
    required this.currency,
    required this.addOns,
  });

  /// The provider's authoritative amount — the only price that exists.
  final double providerPrice;
  final double addOnsTotal;
  final double total;
  final String currency;
  final List<AddOnSelection> addOns;

  @override
  Widget build(BuildContext context) {
    final typography = _type(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.tokigoColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.tokigoColors.outline),
      ),
      child: Column(
        children: <Widget>[
          _Row(
            label: l10n.checkoutProviderPrice,
            value: providerPrice,
            currency: currency,
          ),
          for (final addon in addOns)
            _Row(
              label: '${addon.label} ×${addon.quantity}',
              value: addon.total,
              currency: currency,
            ),
          Divider(
            height: AppSpacing.xl,
            thickness: 1,
            color: context.tokigoColors.hairline,
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.total,
                  style: typography.bodyLargeMedium.copyWith(
                    color: context.tokigoColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$currency ${total.toStringAsFixed(2)}',
                style: typography.title.copyWith(color: context.tokigoColors.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.currency,
  });

  final String label;
  final double value;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final typography = _type(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: typography.body.copyWith(color: context.tokigoColors.textSecondary),
            ),
          ),
          Text(
            '$currency ${value.toStringAsFixed(2)}',
            style: typography.bodyMedium.copyWith(color: context.tokigoColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// The provider's own refusal, verbatim, above the light bar — never a toast
/// that can be missed while the finger is on the button (doc 21 §6).
class _FailureStrip extends StatelessWidget {
  const _FailureStrip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        color: context.tokigoColors.dangerContainer,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 20,
              color: context.tokigoColors.onDangerContainer,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: _type(context).caption.copyWith(
                  color: context.tokigoColors.onDangerContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Space the pinned bar occupies: its 12dp top/bottom padding, the 52dp CTA,
/// and the system navigation inset.
double _barClearance(BuildContext context) =>
    AppSpacing.md * 2 + 52 + MediaQuery.viewPaddingOf(context).bottom;

/// The failure strip's reserve when one is showing: 12dp padding around a
/// three-line caption at the narrowest supported width. The list's clearance
/// grows with it so the breakdown card is never covered by the strip.
const double _failureStripReserve = AppSpacing.md * 2 + 51;

/// The type scale for the active brightness — the light and dark palettes
/// carry different text colours, so the scale is resolved per surface.
AppTypography _type(BuildContext context) =>
    context.isDark ? AppTypography.forDark() : AppTypography.forLight();
