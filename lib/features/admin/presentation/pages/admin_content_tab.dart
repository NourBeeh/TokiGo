import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/admin/admin_home_content_service.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/widgets/step_progress.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/features/admin/presentation/admin_services.dart';
import 'package:tokigo/features/admin/presentation/widgets/admin_card_editor_sheet.dart';

/// Home content management (ADM-A2): sections + cards CRUD, visibility,
/// drafts/publish, scheduling fields via the card editor, reordering.
///
/// Admin density (doc 23 §10): a `label` 11/600 table header, `body` 15/400
/// cells, 48pt rows, the Bag status-pill palette and `lg` 16 gaps — the
/// editorial rhythm is deliberately compressed here.
class AdminContentTab extends ConsumerStatefulWidget {
  const AdminContentTab({super.key});

  @override
  ConsumerState<AdminContentTab> createState() => _AdminContentTabState();
}

/// The width of the "cards" column.
const double _cardsColumn = 56;

/// The width of the "status" column (the pill and the switch).
const double _statusColumn = 180;

/// The width of the disclosure column (the 20pt chevron and its gap).
const double _disclosureColumn = 32;

class _AdminContentTabState extends ConsumerState<AdminContentTab> {
  List<AdminHomeSectionView>? _sections;
  String? _error;
  bool _busy = false;

  /// The sections whose cards are open.
  final Set<String> _expanded = <String>{};

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
      final sections = await ref
          .read(adminContentServiceProvider)
          .listSections();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.adminSaved)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
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
        child: SingleChildScrollView(
          child: AppMessageState(
            icon: Icons.cloud_off_rounded,
            hue: AppColors.danger,
            title: l10n.adminError,
            body: _error ?? l10n.adminError,
            actionLabel: l10n.adminRetry,
            onAction: _busy ? null : _reload,
          ),
        ),
      );
    }
    final sections = _sections;
    if (sections == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (sections.isEmpty) {
      return Center(child: Text(l10n.adminEmpty, style: typography.body));
    }
    return Stack(
      children: <Widget>[
        ListView(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            // Room for the floating action, plus the safe area.
            96 + MediaQuery.paddingOf(context).bottom,
          ),
          children: <Widget>[
            _TableHeader(
              leading: l10n.adminTableSection,
              trailing: l10n.adminTableStatus,
              middle: l10n.adminTableCards,
            ),
            for (final AdminHomeSectionView section in sections) ...<Widget>[
              _SectionRow(
                section: section,
                expanded: _expanded.contains(section.id),
                busy: _busy,
                onToggleExpanded: () => setState(() {
                  if (!_expanded.remove(section.id)) _expanded.add(section.id);
                }),
                onToggleVisibility: (value) => _run(
                  () => ref
                      .read(adminContentServiceProvider)
                      .updateSection(
                        sectionId: section.id,
                        patch: <String, dynamic>{'isVisible': value},
                      ),
                ),
              ),
              if (_expanded.contains(section.id))
                _SectionDetail(
                  section: section,
                  busy: _busy,
                  onMove: (up) => _moveSection(sections, section, up),
                  onDelete: () => _run(
                    () => ref
                        .read(adminContentServiceProvider)
                        .deleteSection(section.id),
                  ),
                  onCreateCard: () => _openCardEditor(section),
                  onEditCardFull: (card) => _openCardEditor(section, card),
                  onDeleteCard: (cardId) => _run(
                    () => ref
                        .read(adminContentServiceProvider)
                        .deleteCard(cardId),
                  ),
                  onToggleCardVisibility: (cardId, value) => _run(
                    () => ref
                        .read(adminContentServiceProvider)
                        .updateCard(
                          cardId: cardId,
                          patch: <String, dynamic>{'isVisible': value},
                        ),
                  ),
                  onToggleCardStatus: (cardId, draft) => _run(
                    () => ref
                        .read(adminContentServiceProvider)
                        .updateCard(
                          cardId: cardId,
                          patch: <String, dynamic>{
                            'status': draft ? 'draft' : 'published',
                          },
                        ),
                  ),
                ),
            ],
          ],
        ),
        PositionedDirectional(
          end: AppSpacing.lg,
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
    AdminHomeSectionView section,
    bool up,
  ) async {
    final index = sections.indexWhere((s) => s.id == section.id);
    final target = up ? index - 1 : index + 1;
    if (index < 0 || target < 0 || target >= sections.length) return;
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
    final layouts = <String>[
      'horizontal',
      'horizontalpeek',
      'grid',
      'vertical',
    ];
    var layout = 'horizontal';
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
              Text(l10n.adminAddSection, style: AppTypography.forLight().title),
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
                  labelText: l10n.adminLayout,
                  border: const OutlineInputBorder(),
                ),
                items: layouts
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
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
      () => ref
          .read(adminContentServiceProvider)
          .createSection(
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
        () => ref
            .read(adminContentServiceProvider)
            .createCard(
              card: <String, dynamic>{...patch, 'sectionId': section.id},
            ),
      );
    }
  }
}

/// The table header — `label` 11/600 `textTertiary`, tracking +0.3.
class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.leading,
    required this.middle,
    required this.trailing,
  });

  /// The first column's title.
  final String leading;

  /// The middle column's title.
  final String middle;

  /// The last column's title.
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final TextStyle style = typography.label.copyWith(
      color: AppColors.textTertiary,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: _disclosureColumn,
              ),
              child: Text(leading, style: style),
            ),
          ),
          SizedBox(
            width: _cardsColumn,
            child: Text(middle, style: style),
          ),
          SizedBox(
            width: _statusColumn,
            child: Text(trailing, style: style),
          ),
        ],
      ),
    );
  }
}

/// One section — a 48pt record row that discloses its cards.
class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.section,
    required this.expanded,
    required this.busy,
    required this.onToggleExpanded,
    required this.onToggleVisibility,
  });

  final AdminHomeSectionView section;
  final bool expanded;
  final bool busy;
  final VoidCallback onToggleExpanded;
  final void Function(bool value) onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();

    return InkWell(
      onTap: onToggleExpanded,
      child: Semantics(
        label: section.title,
        button: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: _disclosureColumn,
                child: Icon(
                  expanded
                      ? Icons.expand_more_rounded
                      : Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ),
              Expanded(
                child: Text(
                  section.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.body.copyWith(color: AppColors.textPrimary),
                ),
              ),
              SizedBox(
                width: _cardsColumn,
                child: Text(
                  '${section.cards.length}',
                  style: typography.body.copyWith(color: AppColors.textPrimary),
                ),
              ),
              SizedBox(
                width: _statusColumn,
                child: Row(
                  children: <Widget>[
                    Flexible(child: _StatusPill(status: section.status)),
                    const Spacer(),
                    Switch(
                      value: section.isVisible,
                      onChanged: busy ? null : onToggleVisibility,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The open section: its cards, then the section's own actions.
class _SectionDetail extends StatelessWidget {
  const _SectionDetail({
    required this.section,
    required this.busy,
    required this.onMove,
    required this.onDelete,
    required this.onCreateCard,
    required this.onEditCardFull,
    required this.onDeleteCard,
    required this.onToggleCardVisibility,
    required this.onToggleCardStatus,
  });

  final AdminHomeSectionView section;
  final bool busy;
  final void Function(bool up) onMove;
  final VoidCallback onDelete;
  final VoidCallback onCreateCard;
  final void Function(AdminHomeCardView card) onEditCardFull;
  final void Function(String cardId) onDeleteCard;
  final void Function(String cardId, bool value) onToggleCardVisibility;
  final void Function(String cardId, bool draft) onToggleCardStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: _disclosureColumn),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final AdminHomeCardView card in section.cards)
            _CardRow(
              card: card,
              busy: busy,
              onEdit: () => onEditCardFull(card),
              onDelete: () => onDeleteCard(card.id),
              onToggleVisibility: (value) =>
                  onToggleCardVisibility(card.id, value),
              onToggleStatus: (draft) => onToggleCardStatus(card.id, draft),
            ),
          // The section's own actions: reorder, delete, add a card.
          SizedBox(
            height: 48,
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: l10n.adminMoveUp,
                  onPressed: busy ? null : () => onMove(true),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                ),
                IconButton(
                  tooltip: l10n.adminMoveDown,
                  onPressed: busy ? null : () => onMove(false),
                  icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                ),
                IconButton(
                  tooltip: l10n.adminDelete,
                  onPressed: busy ? null : onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
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
          ),
        ],
      ),
    );
  }
}

/// One card — a 48pt record row.
class _CardRow extends StatelessWidget {
  const _CardRow({
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

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: <Widget>[
          Icon(_iconFor(card.cardType), size: 20, color: AppColors.brand),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              card.content['title']?.toString() ?? card.id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.body.copyWith(color: AppColors.textPrimary),
            ),
          ),
          Flexible(child: _StatusPill(status: card.status)),
          Switch(
            value: card.isVisible,
            onChanged: busy ? null : onToggleVisibility,
          ),
          PopupMenuButton<String>(
            tooltip: l10n.adminEditCard,
            enabled: !busy,
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onSelected: (String value) {
              switch (value) {
                case 'edit':
                  onEdit();
                case 'delete':
                  onDelete();
                case 'status':
                  onToggleStatus(card.status != 'draft');
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'edit',
                child: Text(l10n.adminEditCard),
              ),
              PopupMenuItem<String>(
                value: 'status',
                child: Text(
                  card.status == 'draft'
                      ? l10n.adminPublished
                      : l10n.adminDraft,
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(l10n.adminDelete),
              ),
            ],
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

/// The status pill — the Bag palette (doc 22 §1.3).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool isDraft = status == 'draft';
    return StatusChip(
      label: isDraft ? l10n.adminDraft : l10n.adminPublished,
      color: isDraft
          ? AppColors.onWarningContainer
          : AppColors.onSuccessContainer,
      container: isDraft
          ? AppColors.warningContainer
          : AppColors.successContainer,
    );
  }
}
