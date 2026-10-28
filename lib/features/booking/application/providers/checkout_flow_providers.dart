import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A traveller/guest entered during the booking funnel.
class TravelerForm {
  const TravelerForm({
    this.firstName = '',
    this.lastName = '',
    this.dob,
    this.gender = '',
    this.nationality = '',
    this.documentType = '',
    this.documentNumber = '',
    this.documentIssueCountry = '',
    this.documentExpiry = '',
  });

  final String firstName;
  final String lastName;
  final String? dob;
  final String gender;
  final String nationality;
  final String documentType;
  final String documentNumber;
  final String documentIssueCountry;
  final String documentExpiry;
}

/// Contact details shared across the funnel.
class ContactForm {
  const ContactForm({this.email = '', this.phone = ''});

  final String email;
  final String phone;
}

/// Selected add-on with quantity (seats, baggage, insurance…).
class AddOnSelection {
  const AddOnSelection({
    required this.id,
    required this.label,
    required this.price,
    this.quantity = 1,
  });

  final String id;
  final String label;
  final double price;
  final int quantity;

  double get total => price * quantity;
}

/// Payment method picked at checkout.
enum PaymentMethod { card, wallet, payAtHotel }

/// The single source of truth for the booking funnel pages.
class CheckoutFlowState {
  const CheckoutFlowState({
    this.travelers = const <TravelerForm>[],
    this.contact = const ContactForm(),
    this.addOns = const <AddOnSelection>[],
    this.paymentMethod = PaymentMethod.card,
    this.basePrice = 0,
    this.currency = 'USD',
  });

  final List<TravelerForm> travelers;
  final ContactForm contact;
  final List<AddOnSelection> addOns;
  final PaymentMethod paymentMethod;
  final double basePrice;
  final String currency;

  double get addOnsTotal => addOns.fold(0, (sum, a) => sum + a.total);

  double get grandTotal => basePrice + addOnsTotal;

  CheckoutFlowState copyWith({
    List<TravelerForm>? travelers,
    ContactForm? contact,
    List<AddOnSelection>? addOns,
    PaymentMethod? paymentMethod,
    double? basePrice,
    String? currency,
  }) => CheckoutFlowState(
    travelers: travelers ?? this.travelers,
    contact: contact ?? this.contact,
    addOns: addOns ?? this.addOns,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    basePrice: basePrice ?? this.basePrice,
    currency: currency ?? this.currency,
  );
}

/// Funnel page 2 writes travellers here.
final checkoutTravelersProvider = StateProvider<List<TravelerForm>>(
  (ref) => const <TravelerForm>[],
);

/// Funnel page 2 writes contact here.
final checkoutContactProvider = StateProvider<ContactForm>(
  (ref) => const ContactForm(),
);

/// Funnel page 3 writes add-ons here.
final checkoutAddOnsProvider = StateProvider<List<AddOnSelection>>(
  (ref) => const <AddOnSelection>[],
);

/// Funnel page 4 writes the picked payment method here.
final checkoutPaymentMethodProvider = StateProvider<PaymentMethod>(
  (ref) => PaymentMethod.card,
);

/// Base offer price set when the funnel starts (booking review).
final checkoutBasePriceProvider = StateProvider<double>((ref) => 0);

final checkoutCurrencyProvider = StateProvider<String>((ref) => 'USD');
