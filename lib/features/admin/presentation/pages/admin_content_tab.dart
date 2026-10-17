import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/admin/admin_home_content_service.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import '../admin_services.dart';
import '../widgets/admin_card_editor_sheet.dart';

/// Home content management (ADM-A2): sections + cards CRUD, visibility,
/// drafts/publish, scheduling fields via the card editor, reordering.
class AdminContentTab extends ConsumerStatefulWidget {
  const AdminContentTab({super.key});

  @override
  ConsumerState<AdminContentTab> createState() => _AdminContentTabState();
}

class _AdminContentTabState extends ConsumerState<AdminContentTab> {
  List<AdminHomeSectionView>? _sections;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _error = null;
    });
    try {
      final sections =
          await ref.read(adminContentServiceProvider).listSections();
      if (!mounted) return;
      setState(() => _sections = sections);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await action();
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminSaved)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typography = AppTypography.forLight();
    if (_error != null && _sections == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(l10n.adminError, style: typography.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: l10n.adminRetry,
              onPressed: _busy ? null : _reload,
              size: AppButtonSize.sm,
            ),
          ],
        ),
      );
    }
    final sections = _sections;
    if (sections == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (sections.isEmpty) {
      return Center(child: Text(l10n.adminEmpty, style: typography.bodyMedium));
    }
    return Stack(
      children: <Widget>[
        ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: sections.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) => _SectionTile(
            section: sections[index],
            isFirst: index == 0,
            isLast: index == sections.length - 1,
            busy: _busy,
            onMove: (up) => _moveSection(sections, index, up),
            onToggleVisibility: (value) => _run(
              () => ref.read(adminContentServiceProvider).updateSection(
                    sectionId: sections[index].id,
                    patch: <String, dynamic>{'isVisible': value},
                  ),
            ),
            onDelete: () => _run(
              () => ref
                  .read(adminContentServiceProvider)
                  .deleteSection(sections[index].id),
            ),
            onEditCard: (cardId, patch) => _run(
              () => ref
                  .read(adminContentServiceProvider)
                  .updateCard(cardId: cardId, patch: patch),
            ),
            onCreateCard: () => _openCardEditor(sections[index]),
            onEditCardFull: (card) => _openCardEditor(sections[index], card),
            onDeleteCard: (cardId) => _run(
              () => ref
                  .read(adminContentServiceProvider)
                  .deleteCard(cardId),
            ),
            onToggleCardVisibility: (cardId, value) => _run(
              () => ref.read(adminContentServiceProvider).updateCard(
                    cardId: cardId,
                    patch: <String, dynamic>{'isVisible': value},
                  ),
            ),
            onToggleCardStatus: (cardId, draft) => _run(
              () => ref.read(adminContentServiceProvider).updateCard(
                    cardId: cardId,
                    patch: <String, dynamic>{
                      'status': draft ? 'draft' : 'published'
                    },
                  ),
            ),
          ),
        ),
        Positioned(
          right: AppSpacing.lg,
          bottom: AppSpacing.lg,
          child: FloatingActionButton.extended(
            heroTag: 'admin-add-section',
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            onPressed: _busy ? null : () => _createSection(context),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.adminAddSection),
          ),
        ),
      ],
    );
  }

  Future<void> _moveSection(
    List<AdminHomeSectionView> sections,
    int index,
    bool up,
  ) async {
    final target = up ? index - 1 : index + 1;
    if (target < 0 || target >= sections.length) return;
    final ids = sections.map((s) => s.id).toList();
    final moved = ids.removeAt(index);
    ids.insert(target, moved);
    await _run(
      () => ref.read(adminContentServiceProvider).reorderSections(ids),
    );
  }

  Future<void> _createSection(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final titleController = TextEditingController();
    final layouts = <String>['horizontal', 'horizontalpeek', 'grid', 'vertical'];
    var layout = 'horizontal';
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.adminAddSection,
                  style: AppTypography.forLight().title),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: l10n.adminTitle,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: layout,
                decoration: InputDecoration(
                  labelText: 'Layout',
                  border: const OutlineInputBorder(),
                ),
                items: layouts
                    .map((value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setSheetState(() => layout = value ?? layout),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton(
                      label: l10n.adminCancel,
                      type: AppButtonType.ghost,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  Expanded(
                    child: AppButton(
                      label: l10n.adminSave,
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true) return;
    final title = titleController.text.trim();
    if (title.isEmpty) return;
    await _run(
      () => ref.read(adminContentServiceProvider).createSection(
            section: <String, dynamic>{'title': title, 'layout': layout},
          ),
    );
  }

  Future<void> _openCardEditor(
    AdminHomeSectionView section, [
    AdminHomeCardView? card,
  ]) async {
    final patch = await showAdminCardEditor(context: context, card: card);
    if (patch == null) return;
    if (card != null) {
      await _run(
        () => ref
            .read(adminContentServiceProvider)
            .updateCard(cardId: card.id, patch: patch),
      );
    } else {
      await _run(
        () => ref.read(adminContentServiceProvider).createCard(
              card: <String, dynamic>{
                ...patch,
                'sectionId': section.id,
              },
            ),
      );
    }
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.section,
    required this.isFirst,
    required this.isLast,
    required this.busy,
    required this.onMove,
    required this.onToggleVisibility,
    required this.onDelete,
    required this.onEditCard,
    required this.onCreateCard,
    required this.onEditCardFull,
    required this.onDeleteCard,
    required this.onToggleCardVisibility,
    required this.onToggleCardStatus,
  });

  final AdminHomeSectionView section;
  final bool isFirst;
  final bool isLast;
  final bool busy;
  final void Function(bool up) onMove;
  final void Function(bool value) onToggleVisibility;
  final VoidCallback onDelete;
  final void Function(String cardId, Map<String, dynamic> patch) onEditCard;
  final VoidCallback onCreateCard;
  final void Function(AdminHomeCardView card) onEditCardFull;
  final void Function(String cardId) onDeleteCard;
  final void Function(String cardId, bool value) onToggleCardVisibility;
  final void Function(String cardId, bool draft) onToggleCardStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typography = AppTypography.forLight();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outline),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          initiallyExpanded: false,
          title: Text(
            section.title,
            style: typography.bodyLargeMedium
                .copyWith(color: AppColors.textPrimary),
          ),
          subtitle: Text(
            '${section.layout} · ${section.cards.length} ${l10n.adminContent}',
            style: typography.caption.copyWith(color: AppColors.textSecondary),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _StatusChip(status: section.status),
              Switch(value: section.isVisible, onChanged: busy ? null : onToggleVisibility),
            ],
          ),
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: l10n.adminMoveUp,
                  onPressed: busy || isFirst ? null : () => onMove(true),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
                IconButton(
                  tooltip: l10n.adminMoveDown,
                  onPressed: busy || isLast ? null : () => onMove(false),
                  icon: const Icon(Icons.arrow_downward_rounded),
                ),
                IconButton(
                  tooltip: l10n.adminDelete,
                  onPressed: busy ? null : onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: AppButton(
                    label: l10n.adminAddCard,
                    type: AppButtonType.secondary,
                    size: AppButtonSize.sm,
                    leadingIcon: Icons.add_rounded,
                    onPressed: busy ? null : onCreateCard,
                  ),
                ),
              ],
            ),
            for (final card in section.cards)
              _CardTile(
                card: card,
                busy: busy,
                onEdit: () => onEditCardFull(card),
                onDelete: () => onDeleteCard(card.id),
                onToggleVisibility: (value) =>
                    onToggleCardVisibility(card.id, value),
                onToggleStatus: (draft) => onToggleCardStatus(card.id, draft),
              ),
          ],
        ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.card,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleVisibility,
    required this.onToggleStatus,
  });

  final AdminHomeCardView card;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(bool value) onToggleVisibility;
  final void Function(bool draft) onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typography = AppTypography.forLight();
    return ListTile(
      leading: Icon(
        _iconFor(card.cardType),
        color: AppColors.brand,
      ),
      title: Text(
        card.content['title']?.toString() ?? card.id,
        style: typography.bodyMedium.copyWith(color: AppColors.textPrimary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StatusChip(status: card.status),
          const SizedBox(width: AppSpacing.sm),
          Text(
            card.cardType,
            style: typography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: l10n.adminDraft,
            onPressed: busy ? null : () => onToggleStatus(card.status != 'draft'),
            icon: Icon(
              card.status == 'draft'
                  ? Icons.edit_off_rounded
                  : Icons.check_circle_outline_rounded,
            ),
          ),
          Switch(value: card.isVisible, onChanged: busy ? null : onToggleVisibility),
          IconButton(
            tooltip: l10n.adminEditCard,
            onPressed: busy ? null : onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: l10n.adminDelete,
            onPressed: busy ? null : onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String type) {
    switch (type.toLowerCase()) {
      case 'flight':
        return Icons.flight_rounded;
      case 'hotel':
        return Icons.hotel_rounded;
      case 'car':
        return Icons.directions_car_rounded;
      case 'package':
        return Icons.luggage_rounded;
      case 'destination':
        return Icons.location_on_rounded;
      default:
        return Icons.local_offer_rounded;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDraft = status == 'draft';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isDraft
            ? AppColors.warning.withValues(alpha: 0.12)
            : AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        isDraft ? l10n.adminDraft : l10n.adminPublished,
        style: AppTypography.forLight().caption.copyWith(
              color: isDraft ? AppColors.warning : AppColors.success,
            ),
      ),
    );
  }
}
