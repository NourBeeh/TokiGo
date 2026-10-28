import 'package:flutter/material.dart';

/// Formats a monetary value into the canonical compact card string (`USD 199`).
///
/// Centralised here so [CardPrice], [CardPriceBlock] and — later — feature
/// cards share exactly one price-formatting implementation instead of
/// re-inlining `'$cur ${value.toStringAsFixed(0)}'`.
String formatCardPrice({
  double? price,
  String? currency,
  bool showCurrency = true,
}) {
  final value = price;
  if (value == null) return '';
  final cur = currency ?? 'USD';
  final amount = value.toStringAsFixed(0);
  return showCurrency ? '$cur $amount' : amount;
}

class CardPrice extends StatelessWidget {
  final double? price;
  final String? currency;
  final double? rawPrice;

  /// Optional override so cards rendering the price over a dark gradient
  /// scrim can keep it legible (e.g. [Colors.white]).
  final Color? color;

  const CardPrice({
    super.key,
    this.price,
    this.currency,
    this.rawPrice,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final value = price ?? rawPrice;
    if (value == null) return const SizedBox.shrink();
    return Text(
      formatCardPrice(price: value, currency: currency),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}
