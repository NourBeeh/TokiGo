import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/core/widgets/pressable.dart';
import 'package:tokigo/core/widgets/step_progress.dart';
import 'package:tokigo/core/widgets/sticky_cta_bar.dart';
import 'package:tokigo/features/booking/application/providers/checkout_flow_providers.dart';
import 'package:tokigo/features/search/application/controllers/flight_search_controller.dart';
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Step 2 of the booking funnel — traveller/guest details.
///
/// Contact block + a form card per traveller with validation before the
/// Continue CTA unlocks. State lives in [checkoutTravelersProvider] so the
/// funnel pages share it.
class PassengerDetailsPage extends ConsumerStatefulWidget {
  const PassengerDetailsPage({super.key});

  @override
  ConsumerState<PassengerDetailsPage> createState() =>
      _PassengerDetailsPageState();
}

class _PassengerDetailsPageState extends ConsumerState<PassengerDetailsPage> {
  late final List<_TravelerController> _travelers;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _phoneCountryCode;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final travelers = ref.read(checkoutTravelersProvider);
    _travelers = <_TravelerController>[
      for (final t in travelers) _TravelerController.from(t),
    ];
    if (_travelers.isEmpty) {
      // A flight search hands off the party it ran for, so the funnel starts
      // with the same number of travellers (the flight counterpart of the
      // hotel occupancy → guest-page hand-off). Anything else — a car or
      // package offer, or no flight search — keeps the single-traveller
      // default rather than inheriting a stale flight party.
      final composition = ref.read(flightPassengerCompositionProvider);
      final bool isFlight =
          ref.read(selectedOfferProvider)?.offerType == 'flight';
      if (isFlight && !composition.isEmpty) {
        for (int i = 0; i < composition.adults; i++) {
          _travelers.add(
            _TravelerController.from(
              const TravelerForm(passengerType: 'adult'),
            ),
          );
        }
        for (int i = 0; i < composition.children; i++) {
          _travelers.add(
            _TravelerController.from(
              const TravelerForm(passengerType: 'child'),
            ),
          );
        }
        for (int i = 0; i < composition.infants; i++) {
          _travelers.add(
            _TravelerController.from(
              const TravelerForm(passengerType: 'infant'),
            ),
          );
        }
      } else {
        _travelers.add(_TravelerController.from(const TravelerForm()));
      }
    }
    final contact = ref.read(checkoutContactProvider);
    _email = TextEditingController(text: contact.email);
    _phone = TextEditingController(text: contact.phone);
    _phoneCountryCode = TextEditingController(text: contact.phoneCountryCode);
  }

  @override
  void dispose() {
    for (final t in _travelers) {
      t.dispose();
    }
    _email.dispose();
    _phone.dispose();
    _phoneCountryCode.dispose();
    super.dispose();
  }

  bool get _isValid {
    final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text);
    final phoneOk = _phone.text.trim().length >= 8;
    // LiteAPI requires the calling code separately (1-3 digits, no '+').
    final countryCodeOk = RegExp(r'^\d{1,3}$').hasMatch(
      _phoneCountryCode.text.trim(),
    );
    final travelersOk = _travelers.every((t) => t.isValid);
    // An infant must name the adult it travels with, and that reference must
    // still resolve to an adult in the current list.
    final infantsOk = _travelers.every(
      (t) => t.hasValidAccompanyingAdult(_travelers),
    );
    return emailOk && phoneOk && countryCodeOk && travelersOk && infantsOk;
  }

  void _continue() {
    if (!_isValid) {
      setState(() => _showErrors = true);
      return;
    }
    ref.read(checkoutTravelersProvider.notifier).state = <TravelerForm>[
      for (final t in _travelers) t.toForm(),
    ];
    ref.read(checkoutContactProvider.notifier).state = ContactForm(
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      phoneCountryCode: _phoneCountryCode.text.trim(),
    );
    context.push('/booking/review/add-ons');
  }

  void _addTraveler() {
    setState(() {
      _travelers.add(_TravelerController.from(const TravelerForm()));
    });
  }

  void _removeTraveler(int index) {
    setState(() => _travelers.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.tokigoColors.background,
      body: SafeArea(
        // `bottom: false` left the page's last row under the Android
        // navigation bar (the pill it was written for is gone).
        child: AiEntranceAnimation(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _FlowHeader(title: l10n.passengerDetails, step: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: <Widget>[
                    for (int i = 0; i < _travelers.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _TravelerCard(
                          controller: _travelers[i],
                          index: i,
                          removable: _travelers.length > 1,
                          onRemove: () => _removeTraveler(i),
                          showErrors: _showErrors,
                          adultLabels: <int, String>{
                            for (int j = 0; j < _travelers.length; j++)
                              if (_travelers[j].passengerType == 'adult')
                                j: _travelers[j].firstName.text.trim().isNotEmpty
                                    ? _travelers[j].firstName.text.trim()
                                    : '${l10n.passengerDetails} ${j + 1}',
                          },
                          accompanyingAdultError: _showErrors &&
                                  !_travelers[i]
                                      .hasValidAccompanyingAdult(_travelers)
                              ? l10n.bookingAccompanyingAdultRequired
                              : null,
                        ),
                      ),
                    AppButton(
                      label: l10n.bookingAddTraveller,
                      type: AppButtonType.secondary,
                      leadingIcon: Icons.person_add_alt_rounded,
                      onPressed: _addTraveler,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      l10n.bookingContactInformation,
                      style: typography.title.copyWith(
                        color: context.tokigoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ContactFields(
                      email: _email,
                      phone: _phone,
                      phoneCountryCode: _phoneCountryCode,
                      showErrors: _showErrors,
                    ),
                    const SizedBox(height: 140),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: StickyCtaBar(
        child: Row(
          children: <Widget>[
            // The funnel's light bar always states the real total (doc 21 §2.1).
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
                  '${ref.watch(checkoutCurrencyProvider)} '
                  '${ref.watch(checkoutBasePriceProvider).toStringAsFixed(2)}',
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
                label: l10n.continueAction,
                trailingIcon: Icons.chevron_right_rounded,
                onPressed: _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header shared by the funnel pages
// ---------------------------------------------------------------------------

class _FlowHeader extends StatelessWidget {
  const _FlowHeader({required this.title, required this.step});

  final String title;
  final int step;

  @override
  Widget build(BuildContext context) {
    return AppPageHeader(
      subtitle: title,
      steps: StepProgress(current: step, total: 4),
      backFallbackLocation: '/booking/review',
    );
  }
}

// ---------------------------------------------------------------------------
// Traveler card
// ---------------------------------------------------------------------------

class _TravelerCard extends StatefulWidget {
  const _TravelerCard({
    required this.controller,
    required this.index,
    required this.removable,
    required this.onRemove,
    required this.showErrors,
    required this.adultLabels,
    this.accompanyingAdultError,
  });

  final _TravelerController controller;
  final int index;
  final bool removable;
  final VoidCallback onRemove;
  final bool showErrors;

  /// Adult travellers an infant may be linked to: traveller index → label.
  final Map<int, String> adultLabels;

  /// Localized error when the infant's accompanying-adult reference is invalid.
  final String? accompanyingAdultError;

  @override
  State<_TravelerCard> createState() => _TravelerCardState();
}

class _TravelerCardState extends State<_TravelerCard> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final bool isInfant = controller.passengerType == 'infant';
    final String typeLabel = _passengerTypeLabel(
      l10n,
      controller.passengerType,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.tokigoColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.tokigoColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                typeLabel.isEmpty
                    ? '${l10n.passengerDetails} ${widget.index + 1}'
                    : '${l10n.passengerDetails} ${widget.index + 1} · $typeLabel',
                style: typography.bodyLargeMedium.copyWith(
                  color: context.tokigoColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (widget.removable)
                Pressable.wrap(
                  child: IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline_rounded,
                      size: 20,
                      color: context.tokigoColors.danger,
                    ),
                    onPressed: widget.onRemove,
                    tooltip: l10n.bookingRemoveTraveller,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _LabeledField(
            fieldKey: Key('traveler-${widget.index}-firstName'),
            label: l10n.bookingFirstName,
            controller: controller.firstName,
            errorText:
                widget.showErrors && controller.firstName.text.trim().isEmpty
                ? l10n.bookingRequiredField
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _LabeledField(
            fieldKey: Key('traveler-${widget.index}-lastName'),
            label: l10n.bookingLastName,
            controller: controller.lastName,
            errorText:
                widget.showErrors && controller.lastName.text.trim().isEmpty
                ? l10n.bookingRequiredField
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _LabeledDropdown<String>(
            fieldKey: Key('traveler-${widget.index}-title'),
            label: l10n.bookingTitleLabel,
            value: controller.title.text,
            options: <String, String>{
              for (final String title in TravelerForm.titleOptions)
                title: _titleLabel(title),
            },
            errorText:
                widget.showErrors && controller.title.text.isEmpty
                ? l10n.bookingRequiredField
                : null,
            onChanged: (String? value) =>
                setState(() => controller.title.text = value ?? ''),
          ),
          const SizedBox(height: AppSpacing.md),
          _LabeledField(
            fieldKey: Key('traveler-${widget.index}-dob'),
            label: 'Date of birth (YYYY-MM-DD)',
            controller: controller.dob,
            errorText: widget.showErrors && controller.dob.text.trim().isEmpty
                ? l10n.bookingRequiredField
                : null,
          ),
          _LabeledField(
            fieldKey: Key('traveler-${widget.index}-gender'),
            label: 'Gender',
            controller: controller.gender,
            errorText: widget.showErrors && controller.gender.text.trim().isEmpty
                ? l10n.bookingRequiredField
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _LabeledField(
            fieldKey: Key('traveler-${widget.index}-nationality'),
            label: 'Nationality (ISO)',
            controller: controller.nationality,
            errorText:
                widget.showErrors && controller.nationality.text.trim().isEmpty
                ? l10n.bookingRequiredField
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _LabeledField(
            fieldKey: Key('traveler-${widget.index}-email'),
            label: l10n.bookingEmailLabel,
            controller: controller.email,
            keyboardType: TextInputType.emailAddress,
            errorText: widget.showErrors &&
                    !_TravelerController.emailPattern
                        .hasMatch(controller.email.text)
                ? l10n.bookingValidEmail
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _LabeledField(
            fieldKey: Key('traveler-${widget.index}-phone'),
            label: l10n.bookingPhoneLabel,
            controller: controller.phone,
            keyboardType: TextInputType.phone,
            errorText:
                widget.showErrors && controller.phone.text.trim().length < 8
                ? l10n.bookingValidPhone
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _LabeledDropdown<String>(
            fieldKey: Key('traveler-${widget.index}-documentType'),
            label: l10n.bookingDocumentTypeLabel,
            value: controller.documentType.text,
            options: <String, String>{
              for (final String type in TravelerForm.documentTypeOptions)
                type: _documentTypeLabel(l10n, type),
            },
            errorText:
                widget.showErrors && controller.documentType.text.isEmpty
                ? l10n.bookingRequiredField
                : null,
            onChanged: (String? value) =>
                setState(() => controller.documentType.text = value ?? ''),
          ),
          const SizedBox(height: AppSpacing.md),
          _LabeledField(
            fieldKey: Key('traveler-${widget.index}-documentNumber'),
            label: l10n.bookingDocumentNumberLabel,
            controller: controller.documentNumber,
            errorText:
                widget.showErrors && controller.documentNumber.text.trim().isEmpty
                ? l10n.bookingRequiredField
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _LabeledField(
            fieldKey: Key('traveler-${widget.index}-documentIssueCountry'),
            label: l10n.bookingDocumentIssueCountryLabel,
            controller: controller.documentIssueCountry,
            errorText:
                widget.showErrors &&
                controller.documentIssueCountry.text.trim().isEmpty
                ? l10n.bookingRequiredField
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _LabeledField(
            fieldKey: Key('traveler-${widget.index}-documentExpiry'),
            label: l10n.bookingDocumentExpiryLabel,
            controller: controller.documentExpiry,
            errorText:
                widget.showErrors && controller.documentExpiry.text.trim().isEmpty
                ? l10n.bookingRequiredField
                : null,
          ),
          if (isInfant) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _LabeledDropdown<int>(
              fieldKey: Key('traveler-${widget.index}-accompanyingAdult'),
              label: l10n.bookingAccompanyingAdultLabel,
              value: controller.accompanyingAdultIndex,
              options: widget.adultLabels,
              errorText: widget.accompanyingAdultError,
              onChanged: (int? value) =>
                  setState(() => controller.accompanyingAdultIndex = value),
            ),
          ],
        ],
      ),
    );
  }

  /// The localized adult/child/infant label shown in the card header.
  String _passengerTypeLabel(AppLocalizations l10n, String type) {
    switch (type) {
      case 'adult':
        return l10n.bookingPassengerTypeAdult;
      case 'child':
        return l10n.bookingPassengerTypeChild;
      case 'infant':
        return l10n.bookingPassengerTypeInfant;
      default:
        return type;
    }
  }

  /// The localized document-type label (stored values are provider tokens).
  String _documentTypeLabel(AppLocalizations l10n, String type) {
    switch (type) {
      case 'passport':
        return l10n.bookingDocumentTypePassport;
      case 'national_id':
        return l10n.bookingDocumentTypeNationalId;
      default:
        return type;
    }
  }

  /// Titles are stored lowercase (Duffel's contract); the label is readable.
  String _titleLabel(String title) {
    switch (title) {
      case 'mr':
        return 'Mr';
      case 'ms':
        return 'Ms';
      case 'mrs':
        return 'Mrs';
      case 'miss':
        return 'Miss';
      default:
        return title;
    }
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.errorText,
    this.keyboardType,
    this.hintText,
    this.fieldKey,
  });

  final String label;
  final TextEditingController controller;
  final String? errorText;
  final TextInputType? keyboardType;
  final String? hintText;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: typography.label),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(errorText: errorText, hintText: hintText),
        ),
      ],
    );
  }
}

/// A labelled dropdown. Empty `value` renders the localized hint, never a
/// silently-selected default.
class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.errorText,
    this.fieldKey,
  });

  final String label;
  final T? value;
  final Map<T, String> options;
  final ValueChanged<T?> onChanged;
  final String? errorText;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final bool hasValue = value != null && options.containsKey(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: typography.label),
        const SizedBox(height: AppSpacing.xs),
        InputDecorator(
          decoration: InputDecoration(errorText: errorText),
          child: DropdownButton<T>(
            key: fieldKey,
            value: hasValue ? value : null,
            isDense: true,
            isExpanded: true,
            hint: Text(l10n.bookingRequiredField, style: typography.body),
            items: <DropdownMenuItem<T>>[
              for (final MapEntry<T, String> entry in options.entries)
                DropdownMenuItem<T>(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _ContactFields extends StatelessWidget {
  const _ContactFields({
    required this.email,
    required this.phone,
    required this.phoneCountryCode,
    required this.showErrors,
  });

  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController phoneCountryCode;
  final bool showErrors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text);
    final countryCodeOk = RegExp(r'^\d{1,3}$').hasMatch(
      phoneCountryCode.text.trim(),
    );
    return Column(
      children: <Widget>[
        _LabeledField(
          fieldKey: const Key('contact-email'),
          label: l10n.bookingEmailLabel,
          controller: email,
          errorText: showErrors && !emailOk ? l10n.bookingValidEmail : null,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // The calling code is a separate LiteAPI field; a wrong width would
            // push the phone number out of its box.
            SizedBox(
              width: 104,
              child: _LabeledField(
                fieldKey: const Key('contact-phoneCountryCode'),
                label: l10n.bookingPhoneCountryCodeLabel,
                controller: phoneCountryCode,
                keyboardType: TextInputType.phone,
                hintText: l10n.bookingPhoneCountryCodeHint,
                errorText: showErrors && !countryCodeOk
                    ? l10n.bookingValidPhoneCountryCode
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _LabeledField(
                fieldKey: const Key('contact-phone'),
                label: l10n.bookingPhoneLabel,
                controller: phone,
                keyboardType: TextInputType.phone,
                errorText: showErrors && phone.text.trim().length < 8
                    ? l10n.bookingValidPhone
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Controllers
// ---------------------------------------------------------------------------

final class _TravelerController {
  _TravelerController()
    : firstName = TextEditingController(),
      lastName = TextEditingController(),
      // OWNER DECISION (2026-10-19): no prefilled birth date. v1 seeded
      // every traveller with 1995-01-01 — a fabricated date of birth that
      // could be submitted to the airline as if it were real. The field
      // starts empty and the continue CTA stays locked until it is typed.
      dob = TextEditingController(),
      // Every field starts EMPTY. A silently-assigned gender, nationality,
      // document type/country/expiry or passport number is fabricated data
      // that would be sent to the airline as if it were real.
      gender = TextEditingController(),
      nationality = TextEditingController(),
      documentType = TextEditingController(),
      documentNumber = TextEditingController(),
      documentIssueCountry = TextEditingController(),
      documentExpiry = TextEditingController(),
      title = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController(),
      passengerType = 'adult';

  factory _TravelerController.from(TravelerForm form) {
    final c = _TravelerController();
    c.firstName.text = form.firstName;
    c.lastName.text = form.lastName;
    if (form.dob != null) c.dob.text = form.dob!;
    c.gender.text = form.gender;
    c.nationality.text = form.nationality;
    c.documentType.text = form.documentType;
    c.documentNumber.text = form.documentNumber;
    c.documentIssueCountry.text = form.documentIssueCountry;
    c.documentExpiry.text = form.documentExpiry;
    c.title.text = form.title;
    c.email.text = form.email;
    c.phone.text = form.phone;
    c.passengerType = form.passengerType;
    c.accompanyingAdultIndex = form.accompanyingAdultIndex;
    return c;
  }

  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController dob;
  final TextEditingController gender;
  final TextEditingController nationality;
  final TextEditingController documentType;
  final TextEditingController documentNumber;
  final TextEditingController documentIssueCountry;
  final TextEditingController documentExpiry;
  final TextEditingController title;
  final TextEditingController email;
  final TextEditingController phone;

  /// 'adult' | 'child' | 'infant' — seeded from the searched party.
  String passengerType;

  /// For an infant: the index of the accompanying adult in the traveller list.
  int? accompanyingAdultIndex;

  static final RegExp emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get isValid =>
      firstName.text.trim().isNotEmpty &&
      lastName.text.trim().isNotEmpty &&
      dob.text.trim().isNotEmpty &&
      gender.text.trim().isNotEmpty &&
      nationality.text.trim().isNotEmpty &&
      documentType.text.trim().isNotEmpty &&
      documentNumber.text.trim().isNotEmpty &&
      documentIssueCountry.text.trim().isNotEmpty &&
      documentExpiry.text.trim().isNotEmpty &&
      title.text.trim().isNotEmpty &&
      emailPattern.hasMatch(email.text) &&
      phone.text.trim().length >= 8;

  /// Whether the infant's accompanying-adult reference still resolves to an
  /// adult traveller in the current list.
  bool hasValidAccompanyingAdult(List<_TravelerController> travelers) {
    if (passengerType != 'infant') return true;
    final index = accompanyingAdultIndex;
    if (index == null || index < 0 || index >= travelers.length) return false;
    return travelers[index].passengerType == 'adult';
  }

  TravelerForm toForm() => TravelerForm(
    firstName: firstName.text.trim(),
    lastName: lastName.text.trim(),
    dob: dob.text.trim(),
    gender: gender.text.trim(),
    nationality: nationality.text.trim(),
    documentType: documentType.text.trim(),
    documentNumber: documentNumber.text.trim(),
    documentIssueCountry: documentIssueCountry.text.trim(),
    documentExpiry: documentExpiry.text.trim(),
    title: title.text.trim(),
    email: email.text.trim(),
    phone: phone.text.trim(),
    passengerType: passengerType,
    accompanyingAdultIndex: accompanyingAdultIndex,
  );

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    dob.dispose();
    gender.dispose();
    nationality.dispose();
    documentType.dispose();
    documentNumber.dispose();
    documentIssueCountry.dispose();
    documentExpiry.dispose();
    title.dispose();
    email.dispose();
    phone.dispose();
  }
}
