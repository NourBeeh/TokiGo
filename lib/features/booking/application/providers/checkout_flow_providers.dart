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
    this.title = '',
    this.email = '',
    this.phone = '',
    this.passengerType = 'adult',
    this.accompanyingAdultIndex,
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

  /// Duffel requires a title per passenger (`DuffelPassengerTitle`).
  final String title;

  /// P3-D5: Duffel requires an email and an E.164 phone for EVERY passenger.
  /// These are per-passenger values — the lead contact is never copied.
  final String email;
  final String phone;

  /// 'adult' | 'child' | 'infant'. Seeded from the searched party so the
  /// booking maps each traveller back to its own offer passenger.
  final String passengerType;

  /// For an infant: the index of the accompanying adult in the traveller list.
  final int? accompanyingAdultIndex;

  /// The title values BOTH flight providers accept (Duffel: mr/ms/mrs/miss/dr,
  /// Nuitee: MR/MS/MRS/MISS). `dr` is intentionally excluded so one collected
  /// value is valid for every provider.
  static const List<String> titleOptions = <String>['mr', 'ms', 'mrs', 'miss'];

  /// The document types the flight providers accept. Each provider maps what
  /// IT supports (`national_id` → LiteAPI `id`); an unsupported type is
  /// omitted by that provider's adapter, never guessed or rewritten.
  static const List<String> documentTypeOptions = <String>[
    'passport',
    'national_id',
  ];
}

/// Contact details shared across the funnel.
class ContactForm {
  const ContactForm({
    this.email = '',
    this.phone = '',
    this.phoneCountryCode = '',
  });

  final String email;
  final String phone;

  /// Calling code WITHOUT '+' (LiteAPI requires it separately). Collected
  /// explicitly — never assumed from the market or the phone number.
  final String phoneCountryCode;
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
