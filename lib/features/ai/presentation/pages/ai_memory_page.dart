import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/features/ai/application/explicit_memory_controller.dart';
import 'package:tokigo/features/ai/application/memory_controls_providers.dart';
import 'package:tokigo/features/ai/domain/explicit_memory_view.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// 2C-C2 — "What I Know About You": explicit conversation memory controls.
///
/// Shows the caller's explicit AI memories (preferred destination / budget
/// / travel style ONLY) as human-readable cards with Edit and Delete, plus
/// a Clear-all action scoped to exactly these rows. The page renders
/// NOTHING raw: no ids, no confidence, no source tags, no JSON. Guests see
/// a sign-in prompt instead — memory is a signed-in surface.
///
/// Route: `/ai-memory` (added to the router alongside `/ai-chat`); opened
/// from the AI chat header.
class AiMemoryPage extends ConsumerWidget {
  const AiMemoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final signedIn = ref.watch(memoryControlsSignedInProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/'),
                    tooltip: l10n.back,
                  ),
                  Text(
                    l10n.aiMemoryTitle,
                    style: typography.title.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: signedIn.maybeWhen(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                data: (ok) => ok
                    ? const _MemoryBody()
                    : _SignInPrompt(l10n: l10n, typography: typography),
                orElse: () => const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.l10n, required this.typography});

  final AppLocalizations l10n;
  final AppTypography typography;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.lock_outline_rounded,
              size: 44,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.aiMemorySignInPrompt,
              textAlign: TextAlign.center,
              style: typography.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => context.go('/auth'),
              child: Text(l10n.signIn),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryBody extends ConsumerWidget {
  const _MemoryBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(explicitMemoryControllerProvider);

    if (state.status == ExplicitMemoryStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.isEmpty) {
      return _EmptyState(
        onRetry: () =>
            ref.read(explicitMemoryControllerProvider.notifier).load(),
      );
    }

    return Column(
      children: <Widget>[
        if (state.errorMessage != null)
          _ErrorBanner(
            message: state.errorMessage!,
            onDismiss: () => ref
                .read(explicitMemoryControllerProvider.notifier)
                .dismissError(),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: state.memories.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final memory = state.memories[index];
              return _MemoryCard(memory: memory);
            },
          ),
        ),
        _ClearAllBar(
          onClearAll: () async {
            final controller =
                ref.read(explicitMemoryControllerProvider.notifier);
            final ok = await controller.clearAll();
            if (ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10nOf(context).aiMemoryClearedAll)),
              );
            }
          },
        ),
      ],
    );
  }

  static AppLocalizations l10nOf(BuildContext context) =>
      AppLocalizations.of(context)!;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.psychology_alt_outlined,
              size: 44,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.aiMemoryEmpty,
              textAlign: TextAlign.center,
              style: typography.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: onRetry, child: Text(l10n.adminRetry)),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryCard extends ConsumerWidget {
  const _MemoryCard({required this.memory});

  final ExplicitMemoryView memory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typography = AppTypography.forLight();
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(explicitMemoryControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              memory.title,
              style: typography.bodyLargeMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              memory.displayValue,
              style: typography.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton.icon(
                  onPressed: () => _openEditor(context, controller),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(l10n.aiMemoryEdit),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final ok = await controller.delete(memory);
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.aiMemoryDeleted),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: Text(l10n.aiMemoryDelete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openEditor(
    BuildContext context,
    ExplicitMemoryController controller,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _MemoryEditorSheet(
        memory: memory,
        controller: controller,
        readError: () =>
            // Reading through the sheet's ancestor scope keeps the
            // provider lookup valid even though the sheet rides a new
            // route below this widget's context.
            ProviderScope.containerOf(sheetContext, listen: false)
                .read(explicitMemoryControllerProvider)
                .errorMessage,
      ),
    );
  }
}

class _ClearAllBar extends StatelessWidget {
  const _ClearAllBar({required this.onClearAll});

  final Future<void> Function() onClearAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
            ),
            onPressed: () => _confirmClearAll(context),
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            label: Text(l10n.aiMemoryClearAll),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.aiMemoryClearAll),
        content: Text(l10n.aiMemoryClearAllConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.adminCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.aiMemoryClearAll),
          ),
        ],
      ),
    );
    if (confirmed == true) await onClearAll();
  }
}

/// Bottom-sheet editor for one explicit memory. Renders a kind-specific
/// field (free destination text / min+max budget / styles chips), validates
/// through [ExplicitMemoryInput] BEFORE any network call, and saves through
/// the controller's `updateValue`.
class _MemoryEditorSheet extends StatefulWidget {
  const _MemoryEditorSheet({
    required this.memory,
    required this.controller,
    required this.readError,
  });

  final ExplicitMemoryView memory;
  final ExplicitMemoryController controller;

  /// Reads the controller's LAST surfaced error through the provider scope
  /// (the sheet is a plain StatefulWidget — no ref of its own).
  final String? Function() readError;

  @override
  State<_MemoryEditorSheet> createState() => _MemoryEditorSheetState();
}

class _MemoryEditorSheetState extends State<_MemoryEditorSheet> {
  late final TextEditingController _destination;
  late final TextEditingController _minBudget;
  late final TextEditingController _maxBudget;
  late final TextEditingController _styles;

  String? _error;

  @override
  void initState() {
    super.initState();
    final value = widget.memory.record.value;
    _destination = TextEditingController(
      text: value['destination']?.toString() ?? '',
    );
    final min = value['min'];
    final max = value['max'];
    _minBudget = TextEditingController(
      text: min is num ? _numText(min) : '',
    );
    _maxBudget = TextEditingController(
      text: max is num ? _numText(max) : '',
    );
    final stylesRaw = value['styles'];
    _styles = TextEditingController(
      text: stylesRaw is List
          ? stylesRaw.map((e) => e.toString()).join(', ')
          : '',
    );
  }

  static String _numText(num n) {
    final d = n.toDouble();
    return d == d.roundToDouble() ? d.round().toString() : d.toString();
  }

  @override
  void dispose() {
    _destination.dispose();
    _minBudget.dispose();
    _maxBudget.dispose();
    _styles.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final kind = widget.memory.kind;
    final error = ExplicitMemoryInput.validate(
      kind: kind,
      destination: _destination.text,
      minBudget: _minBudget.text,
      maxBudget: _maxBudget.text,
      styles: _styles.text,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final ok = await widget.controller.updateValue(
      widget.memory,
      ExplicitMemoryInput.buildValue(
        kind: kind,
        destination: _destination.text,
        minBudget: _minBudget.text,
        maxBudget: _maxBudget.text,
        styles: _styles.text,
      ),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      // The controller already surfaced the failure into its state; the
      // sheet re-reads it through the provider scope callback.
      final error = widget.readError();
      setState(() => _error =
          error ?? 'Something went wrong. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final kind = widget.memory.kind;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        // Keeps the sheet above the keyboard in both text directions.
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.aiMemoryEdit,
            style: typography.title.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (kind == 'preferred_destination')
            TextField(
              controller: _destination,
              maxLength: ExplicitMemoryInput.destinationMaxChars,
              decoration: InputDecoration(
                labelText: l10n.aiMemoryFieldDestination,
                counterText: '',
              ),
            )
          else if (kind == 'preferred_budget')
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _minBudget,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.aiMemoryFieldBudgetMin,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _maxBudget,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.aiMemoryFieldBudgetMax,
                    ),
                  ),
                ),
              ],
            )
          else
            TextField(
              controller: _styles,
              decoration: InputDecoration(
                labelText: l10n.aiMemoryFieldStyles,
                helperText: l10n.aiMemoryFieldStylesHelper,
              ),
            ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: Text(l10n.adminSave),
            ),
          ),
        ],
      ),
    );
  }
}
