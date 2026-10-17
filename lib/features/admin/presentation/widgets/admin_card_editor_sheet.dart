import 'package:flutter/material.dart';

import 'package:tokigo/core/admin/admin_home_content_service.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/features/home/presentation/widgets/home_card.dart';
import 'package:tokigo/l10n/app_localizations.dart';

const List<String> kAdminCardTypes = <String>[
  'flight',
  'hotel',
  'car',
  'package',
  'destination',
  'deal',
];

/// Add/edit card sheet with a live [HomeCard] preview built from the exact
/// widget the home feed renders — the admin sees what the user will see.
Future<Map<String, dynamic>?> showAdminCardEditor({
  required BuildContext context,
  AdminHomeCardView? card,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _AdminCardEditorSheet(card: card),
  );
}

class _AdminCardEditorSheet extends StatefulWidget {
  const _AdminCardEditorSheet({this.card});

  final AdminHomeCardView? card;

  @override
  State<_AdminCardEditorSheet> createState() => _AdminCardEditorSheetState();
}

class _AdminCardEditorSheetState extends State<_AdminCardEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _imageUrl;
  late final TextEditingController _price;
  late final TextEditingController _currency;
  late final TextEditingController _rating;
  late final TextEditingController _badge;
  late final TextEditingController _actionLabel;
  late String _cardType;
  late String _status;

  @override
  void initState() {
    super.initState();
    final content = widget.card?.content ?? const <String, dynamic>{};
    _title = TextEditingController(text: content['title']?.toString() ?? '');
    _subtitle = TextEditingController(text: content['subtitle']?.toString() ?? '');
    _imageUrl = TextEditingController(text: content['imageUrl']?.toString() ?? '');
    _price = TextEditingController(
      text: content['price'] == null ? '' : content['price'].toString(),
    );
    _currency = TextEditingController(text: content['currency']?.toString() ?? 'EGP');
    _rating = TextEditingController(
      text: content['rating'] == null ? '' : content['rating'].toString(),
    );
    _badge = TextEditingController(text: content['badge']?.toString() ?? '');
    _actionLabel = TextEditingController(
      text: (content['actionLabel'] ?? content['action'])?.toString() ?? '',
    );
    _cardType = widget.card?.cardType ?? 'hotel';
    _status = widget.card?.status ?? 'published';
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _imageUrl.dispose();
    _price.dispose();
    _currency.dispose();
    _rating.dispose();
    _badge.dispose();
    _actionLabel.dispose();
    super.dispose();
  }

  HomeItem get _previewItem => HomeItem(
        id: widget.card?.id ?? 'preview',
        type: _typeFor(_cardType),
        title: _title.text.trim(),
        subtitle: _subtitle.text.trim().isEmpty ? null : _subtitle.text.trim(),
        imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
        price: double.tryParse(_price.text.trim()),
        currency: _currency.text.trim().isEmpty ? null : _currency.text.trim(),
        rating: double.tryParse(_rating.text.trim()),
        badge: _badge.text.trim().isEmpty ? null : _badge.text.trim(),
        actionLabel: _actionLabel.text.trim().isEmpty
            ? null
            : _actionLabel.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typography = AppTypography.forLight();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.card == null ? l10n.adminAddCard : l10n.adminEditCard,
              style: typography.title.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _cardType,
                    decoration: InputDecoration(
                      labelText: l10n.adminType,
                      border: const OutlineInputBorder(),
                    ),
                    items: kAdminCardTypes
                        .map((value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _cardType = value ?? _cardType),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: InputDecoration(
                      labelText: l10n.adminStatus,
                      border: const OutlineInputBorder(),
                    ),
                    items: <String>['published', 'draft']
                        .map((value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value == 'draft'
                                    ? l10n.adminDraft
                                    : l10n.adminPublished,
                              ),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _status = value ?? _status),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _field(_title, l10n.adminTitle, onChanged: () => setState(() {})),
            _field(_subtitle, l10n.adminSubtitle,
                onChanged: () => setState(() {})),
            _field(_imageUrl, l10n.adminImageUrl,
                onChanged: () => setState(() {})),
            Row(
              children: <Widget>[
                Expanded(
                    child: _field(_price, l10n.adminPrice,
                        keyboardType: TextInputType.number,
                        onChanged: () => setState(() {}))),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                    child: _field(_currency, l10n.adminCurrency,
                        onChanged: () => setState(() {}))),
              ],
            ),
            Row(
              children: <Widget>[
                Expanded(
                    child: _field(_rating, l10n.adminRating,
                        keyboardType: TextInputType.number,
                        onChanged: () => setState(() {}))),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                    child: _field(_badge, l10n.adminBadge,
                        onChanged: () => setState(() {}))),
              ],
            ),
            _field(_actionLabel, l10n.adminActionLabel,
                onChanged: () => setState(() {})),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.adminPreview,
                style: typography.caption
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(width: 300, child: HomeCard(item: _previewItem)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppButton(
                    label: l10n.adminCancel,
                    type: AppButtonType.ghost,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  child: AppButton(
                    label: l10n.adminSave,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    VoidCallback? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged == null ? null : (_) => onChanged(),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  void _save() {
    final price = double.tryParse(_price.text.trim());
    final rating = double.tryParse(_rating.text.trim());
    Navigator.pop(context, <String, dynamic>{
      'cardType': _cardType,
      'status': _status,
      'content': <String, dynamic>{
        'title': _title.text.trim(),
        if (_subtitle.text.trim().isNotEmpty)
          'subtitle': _subtitle.text.trim(),
        if (_imageUrl.text.trim().isNotEmpty)
          'imageUrl': _imageUrl.text.trim(),
        'price': ?price,
        if (_currency.text.trim().isNotEmpty)
          'currency': _currency.text.trim(),
        'rating': ?rating,
        if (_badge.text.trim().isNotEmpty) 'badge': _badge.text.trim(),
        if (_actionLabel.text.trim().isNotEmpty)
          'actionLabel': _actionLabel.text.trim(),
      },
    });
  }
}

HomeCardType _typeFor(String value) {
  switch (value) {
    case 'flight':
      return HomeCardType.flight;
    case 'car':
      return HomeCardType.car;
    case 'package':
      return HomeCardType.package;
    case 'destination':
      return HomeCardType.destination;
    case 'deal':
      return HomeCardType.deal;
    default:
      return HomeCardType.hotel;
  }
}
