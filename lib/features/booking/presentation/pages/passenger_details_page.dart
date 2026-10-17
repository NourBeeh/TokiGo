import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/widgets/step_progress.dart';
import 'package:tokigo/core/widgets/sticky_cta_bar.dart';
import 'package:tokigo/features/booking/application/providers/checkout_flow_providers.dart';
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
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final travelers = ref.read(checkoutTravelersProvider);
    _travelers = <_TravelerController>[
      for (final t in travelers)
        _TravelerController.from(t),
    ];
    if (_travelers.isEmpty) {
      _travelers.add(_TravelerController.from(const TravelerForm()));
    }
    final contact = ref.read(checkoutContactProvider);
    _email = TextEditingController(text: contact.email);
    _phone = TextEditingController(text: contact.phone);
  }

  @override
  void dispose() {
    for (final t in _travelers) {
      t.dispose();
    }
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _isValid {
    final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text);
    final phoneOk = _phone.text.trim().length >= 8;
    final travelersOk = _travelers.every((t) => t.isValid);
    return emailOk && phoneOk && travelersOk;
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
    );
    context.push('/booking/add-ons');
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
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
                      ),
                    ),
                  AppButton(
                    label: 'Add traveller',
                    type: AppButtonType.secondary,
                    leadingIcon: Icons.person_add_alt_rounded,
                    onPressed: _addTraveler,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Contact information',
                    style: typography.title.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ContactFields(
                    email: _email,
                    phone: _phone,
                    showErrors: _showErrors,
                  ),
                  const SizedBox(height: 140),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: StickyCtaBar(
        child: Row(
          children: <Widget>[
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
    final typography = AppTypography.forLight();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.canPop() ? context.pop() : context.go('/booking/review'),
                tooltip: 'Back',
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                title,
                style: typography.title.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: StepProgress(current: step, total: 3),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Traveler card
// ---------------------------------------------------------------------------

class _TravelerCard extends StatelessWidget {
  const _TravelerCard({
    required this.controller,
    required this.index,
    required this.removable,
    required this.onRemove,
    required this.showErrors,
  });

  final _TravelerController controller;
  final int index;
  final bool removable;
  final VoidCallback onRemove;
  final bool showErrors;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '${l10n.passengerDetails} ${index + 1}',
                style: typography.bodyLargeMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (removable)
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 20,
                    color: AppColors.danger,
                  ),
                  onPressed: onRemove,
                  tooltip: 'Remove traveller',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _LabeledField(
            label: 'First name',
            controller: controller.firstName,
            errorText:
                showErrors && controller.firstName.text.trim().isEmpty
                    ? 'Required'
                    : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _LabeledField(
            label: 'Last name',
            controller: controller.lastName,
            errorText:
                showErrors && controller.lastName.text.trim().isEmpty
                    ? 'Required'
                    : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _LabeledField(
            label: 'Date of birth (YYYY-MM-DD)',
            controller: controller.dob,
            errorText: showErrors && controller.dob.text.trim().isEmpty
                ? 'Required'
                : null,
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: typography.label,
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          decoration: InputDecoration(errorText: errorText),
        ),
      ],
    );
  }
}

class _ContactFields extends StatelessWidget {
  const _ContactFields({
    required this.email,
    required this.phone,
    required this.showErrors,
  });

  final TextEditingController email;
  final TextEditingController phone;
  final bool showErrors;

  @override
  Widget build(BuildContext context) {
    final emailOk =
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text);
    return Column(
      children: <Widget>[
        _LabeledField(
          label: 'Email',
          controller: email,
          errorText: showErrors && !emailOk ? 'Enter a valid email' : null,
        ),
        const SizedBox(height: AppSpacing.md),
        _LabeledField(
          label: 'Phone',
          controller: phone,
          errorText: showErrors && phone.text.trim().length < 8
              ? 'Enter a valid phone'
              : null,
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
        dob = TextEditingController(text: DateFormat('yyyy-MM-dd')
            .format(DateTime(1995, 1, 1)));

  factory _TravelerController.from(TravelerForm form) {
    final c = _TravelerController();
    c.firstName.text = form.firstName;
    c.lastName.text = form.lastName;
    if (form.dob != null) c.dob.text = form.dob!;
    return c;
  }

  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController dob;

  bool get isValid =>
      firstName.text.trim().isNotEmpty &&
      lastName.text.trim().isNotEmpty &&
      dob.text.trim().isNotEmpty;

  TravelerForm toForm() => TravelerForm(
        firstName: firstName.text.trim(),
        lastName: lastName.text.trim(),
        dob: dob.text.trim(),
      );

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    dob.dispose();
  }
}
