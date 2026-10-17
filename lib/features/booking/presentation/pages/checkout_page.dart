import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wetravellers/core/theme/app_colors.dart';
import 'package:wetravellers/core/theme/app_radius.dart';
import 'package:wetravellers/core/theme/app_spacing.dart';
import 'package:wetravellers/core/theme/app_typography.dart';
import 'package:wetravellers/core/ui/app_button.dart';
import 'package:wetravellers/core/widgets/sticky_cta_bar.dart';
import 'package:wetravellers/features/booking/application/providers/checkout_flow_providers.dart';
import 'package:wetravellers/features/booking/application/services/checkout_payment_service.dart';
import 'package:wetravellers/l10n/app_localizations.dart';

/// Step 4 of the booking funnel — payment.
///
/// Full premium checkout UI with mock processing: method selection, new-card
/// form, price breakdown and a simulated 1.6s processing state that always
/// succeeds into the confirmation page.
class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  PaymentMethod _method = PaymentMethod.card;
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

  Future<void> _pay() async {
    if (!_cardValid) {
      setState(() => _showErrors = true);
      return;
    }
    ref.read(checkoutPaymentMethodProvider.notifier).state = _method;
    setState(() => _processing = true);

    // Real backend payment orchestration (spec point 31): intent -> confirm
    // through the market-routed gateway; 3DS/pending and declined states
    // surface exactly like production flows.
    final basePrice = ref.read(checkoutBasePriceProvider);
    final addOnsTotal = ref
        .read(checkoutAddOnsProvider)
        .fold<double>(0, (s, a) => s + a.total);
    final taxes = (basePrice + addOnsTotal) * 0.14;
    final total = basePrice + addOnsTotal + taxes;

    final result = await ref.read(checkoutPaymentServiceProvider).pay(
          bookingId: 'booking-${DateTime.now().millisecondsSinceEpoch}',
          amount: total,
          currency: 'EGP',
          market: 'EG',
          idempotencyKey:
              'pay-${DateTime.now().millisecondsSinceEpoch}-${_method.name}',
          method: switch (_method) {
            PaymentMethod.wallet => 'wallet',
            PaymentMethod.payAtHotel => 'pay_at_hotel',
            PaymentMethod.card => _cardNumber.text.startsWith('4')
                ? 'card'
                : 'card_3ds',
          },
        );

    if (!mounted) return;
    setState(() => _processing = false);

    switch (result.outcome) {
      case PaymentOutcome.succeeded:
      case PaymentOutcome.pending3ds:
        // Pending 3DS completes via the simulated webhook; the funnel
        // proceeds into confirmation (booking follows payment success).
        context.go('/booking/confirmation');
      case PaymentOutcome.failed:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.reason ?? 'Payment declined')),
          );
        }
      case PaymentOutcome.unavailable:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.reason ?? 'Payment unavailable')),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final basePrice = ref.watch(checkoutBasePriceProvider);
    final addOns = ref.watch(checkoutAddOnsProvider);
    final currency = ref.watch(checkoutCurrencyProvider);
    final addOnsTotal = addOns.fold<double>(0, (s, a) => s + a.total);
    final taxes = (basePrice + addOnsTotal) * 0.14;
    final total = basePrice + addOnsTotal + taxes;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: _processing
                        ? null
                        : () => context.canPop() ? context.pop() : context.go('/booking/review'),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    l10n.payment,
                    style: typography.title.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
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
                          'Payment method',
                          style: typography.bodyLargeMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _MethodTile(
                          icon: Icons.credit_card_rounded,
                          label: 'Credit / debit card',
                          selected: _method == PaymentMethod.card,
                          onTap: () =>
                              setState(() => _method = PaymentMethod.card),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _MethodTile(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Digital wallet',
                          selected: _method == PaymentMethod.wallet,
                          onTap: () =>
                              setState(() => _method = PaymentMethod.wallet),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _MethodTile(
                          icon: Icons.hotel_rounded,
                          label: 'Pay at hotel',
                          selected: _method == PaymentMethod.payAtHotel,
                          onTap: () => setState(
                            () => _method = PaymentMethod.payAtHotel,
                          ),
                        ),
                        if (_method == PaymentMethod.card) ...<Widget>[
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Card details',
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
                          'Price breakdown',
                          style: typography.bodyLargeMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _PriceBreakdownCard(
                          basePrice: basePrice,
                          addOnsTotal: addOnsTotal,
                          taxes: taxes,
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
                                  'Processing payment…',
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
      bottomSheet: StickyCtaBar(
        child: Row(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  l10n.total,
                  style: typography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                Text(
                  '$currency ${total.toStringAsFixed(2)}',
                  style: typography.title.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: AppButton(
                label: _method == PaymentMethod.payAtHotel
                    ? 'Confirm booking'
                    : 'Pay ${total.toStringAsFixed(0)}',
                leadingIcon: Icons.lock_rounded,
                onPressed: _processing ? null : _pay,
              ),
            ),
          ],
        ),
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
                    ? const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white)
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
    required this.basePrice,
    required this.addOnsTotal,
    required this.taxes,
    required this.total,
    required this.currency,
    required this.addOns,
  });

  final double basePrice;
  final double addOnsTotal;
  final double taxes;
  final double total;
  final String currency;
  final List<AddOnSelection> addOns;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: <Widget>[
          _Row(label: 'Base fare', value: basePrice, currency: currency),
          for (final addon in addOns)
            _Row(
              label: '${addon.label} ×${addon.quantity}',
              value: addon.total,
              currency: currency,
            ),
          const Divider(height: AppSpacing.xl),
          _Row(label: 'Taxes & fees (14%)', value: taxes, currency: currency),
          const Divider(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Total',
                  style: typography.bodyLargeMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$currency ${total.toStringAsFixed(2)}',
                style: typography.title.copyWith(
                  color: AppColors.textPrimary,
                ),
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
            style: typography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
