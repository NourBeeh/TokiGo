import 'customer_price.dart';

/// A money figure resolved for display: the amount + the currency it is in.
class DisplayMoney {
  const DisplayMoney(this.amount, this.currency);

  final double amount;
  final String currency;
}

/// Resolves the CUSTOMER display amount for a provider figure.
///
/// The backend attaches [CustomerPrice] (the provider amount converted to the
/// traveller's display currency). When it is present we scale the figure the
/// card wants to show (e.g. a derived per-night rate) by the same ratio the
/// quote used, so a per-night price stays in the provider's per-night terms
/// while being stated in the display currency. Without a quote, the provider
/// amount/currency stand unchanged — the app never invents a conversion.
DisplayMoney displayMoneyFor(
  double providerAmount,
  String providerCurrency,
  CustomerPrice? quote,
) {
  if (quote == null ||
      quote.providerAmount <= 0 ||
      quote.customerCurrency.trim().isEmpty) {
    return DisplayMoney(providerAmount, providerCurrency);
  }
  final double ratio = quote.customerAmount / quote.providerAmount;
  return DisplayMoney(providerAmount * ratio, quote.customerCurrency);
}
