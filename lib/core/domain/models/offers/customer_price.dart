import 'package:flutter/foundation.dart';

/// Customer-facing display price attached to every offer by the backend
/// pricing engine (spec point 5/O.6): the provider amount stays untouched
/// next to the converted customer total plus the FX snapshot used.
@immutable
class CustomerPrice {
  const CustomerPrice({
    required this.providerAmount,
    required this.providerCurrency,
    required this.customerAmount,
    required this.customerCurrency,
    required this.pricingVersion,
    required this.expiresAt,
    this.fxSource,
    this.fxRate,
    this.lines = const <PriceLine>[],
  });

  factory CustomerPrice.fromJson(Map<String, dynamic> j) {
    final rawLines = j['lines'];
    final lines = rawLines is List
        ? rawLines
              .whereType<Map>()
              .map((l) => PriceLine.fromJson(Map<String, dynamic>.from(l)))
              .toList()
        : const <PriceLine>[];
    return CustomerPrice(
      providerAmount: (j['providerAmount'] as num?)?.toDouble() ?? 0,
      providerCurrency: j['providerCurrency']?.toString() ?? 'USD',
      customerAmount: (j['customerAmount'] as num?)?.toDouble() ?? 0,
      customerCurrency: j['customerCurrency']?.toString() ?? 'EGP',
      pricingVersion: j['pricingVersion']?.toString() ?? '',
      expiresAt: j['expiresAt']?.toString() ?? '',
      fxSource: j['fx']?['source']?.toString(),
      fxRate: (j['fx']?['rate'] as num?)?.toDouble(),
      lines: lines,
    );
  }

  final double providerAmount;
  final String providerCurrency;
  final double customerAmount;
  final String customerCurrency;
  final String pricingVersion;
  final String expiresAt;
  final String? fxSource;
  final double? fxRate;
  final List<PriceLine> lines;
}

/// One breakdown line of the customer quote (BASE/MARKUP/PAYMENT_FEE/...).
@immutable
class PriceLine {
  const PriceLine({
    required this.type,
    required this.label,
    required this.amount,
    required this.currency,
  });

  factory PriceLine.fromJson(Map<String, dynamic> j) => PriceLine(
    type: j['type']?.toString() ?? 'BASE',
    label: j['label']?.toString() ?? '',
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    currency: j['currency']?.toString() ?? 'EGP',
  );

  final String type;
  final String label;
  final double amount;
  final String currency;
}
