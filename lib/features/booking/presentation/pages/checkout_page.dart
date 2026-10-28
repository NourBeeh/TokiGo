import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/core/widgets/step_progress.dart';
import 'package:tokigo/core/widgets/sticky_cta_bar.dart';
import 'package:tokigo/features/bag/domain/trip.dart';
import 'package:tokigo/features/booking/application/booking_providers.dart';
import 'package:tokigo/features/booking/application/booking_state.dart';
import 'package:tokigo/features/booking/application/providers/checkout_flow_providers.dart';
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
              travelers: _travelers(),
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
    final travelers = ref.read(checkoutTravelersProvider);
    final contact = ref.read(checkoutContactProvider);
    return <Map<String, dynamic>>[
      for (int i = 0; i < travelers.length; i++)
        <String, dynamic>{
          'firstName': travelers[i].firstName,
          'lastName': travelers[i].lastName,
          if (travelers[i].dob != null && travelers[i].dob!.isNotEmpty)
            'dateOfBirth': travelers[i].dob,
          if (i == 0 && contact.email.isNotEmpty) 'email': contact.email,
          if (i == 0 && contact.phone.isNotEmpty) 'phone': contact.phone,
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
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final record = ref.watch(bookingControllerProvider).record;

    // No prepared booking → nothing to pay for. Saying so (with a way back) is
    // the honest version of what v1 faked with a generated booking id.
    if (record == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: AiEntranceAnimation(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppPageHeader(
                  title: l10n.payment,
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: AiEntranceAnimation(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppPageHeader(
                title: l10n.payment,
                // Doc 21 §1 — the funnel is 4 steps; checkout is the last.
                steps: const StepProgress(current: 3, total: 4),
                backFallbackLocation: '/booking/review',
                // Leaving mid-charge is blocked (the body is inert too); the
                // control keeps its place and mutes instead of vanishing.
                backEnabled: !_processing,
              ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: _processing,
                  child: Stack(
                    children: <Widget>[
                      ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: <Widget>[
                          Text(
                            l10n.checkoutPaymentMethod,
                            style: typography.bodyLargeMedium.copyWith(
                              color: AppColors.textPrimary,
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
                                color: AppColors.textPrimary,
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
                              color: AppColors.textPrimary,
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
                          const SizedBox(height: 160),
                        ],
                      ),
                      if (_processing)
                        Positioned.fill(
                          child: ColoredBox(
                            color: AppColors.background.withValues(alpha: 0.7),
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
                                      color: AppColors.textPrimary,
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
              ),
            ],
          ),
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
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '$currency ${total.toStringAsFixed(2)}',
                      maxLines: 1,
                      style: typography.titleMedium.copyWith(
                        color: AppColors.textPrimary,
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
                      '$currency ${total.toStringAsFixed(0)}',
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
              Icon(icon, size: 22, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: typography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
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
                    color: selected ? AppColors.brand : AppColors.outline,
                    width: 2,
                  ),
                  color: selected ? AppColors.brand : Colors.transparent,
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
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
        TextField(
          controller: cardNumber,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Card number',
            hintText: '4242 4242 4242 4242',
            errorText: showErrors && digits.length < 15
                ? 'Enter a valid card number'
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: cardName,
          decoration: InputDecoration(
            labelText: 'Name on card',
            errorText: showErrors && cardName.text.trim().isEmpty
                ? 'Required'
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: expiry,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Expiry',
                  hintText: 'MM/YY',
                  errorText: showErrors && expiry.text.trim().isEmpty
                      ? 'Required'
                      : null,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextField(
                controller: cvc,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'CVC',
                  hintText: '123',
                  errorText: showErrors && cvc.text.trim().length < 3
                      ? '3 digits'
                      : null,
                ),
              ),
            ),
          ],
        ),
      ],
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
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
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
          const Divider(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.total,
                  style: typography.bodyLargeMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$currency ${total.toStringAsFixed(2)}',
                style: typography.title.copyWith(color: AppColors.textPrimary),
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
    final typography = AppTypography.forLight();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: typography.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Text(
            '$currency ${value.toStringAsFixed(2)}',
            style: typography.bodyMedium.copyWith(color: AppColors.textPrimary),
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
        color: AppColors.dangerContainer,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              size: 20,
              color: AppColors.danger,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTypography.forLight().caption.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
