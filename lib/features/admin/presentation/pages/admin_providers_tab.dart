import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/admin/admin_provider_models.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/widgets/step_progress.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/features/admin/presentation/admin_services.dart';

/// API provider management (ADM-B1 + ADM-A2): toggle activity per vertical,
/// reorder priority (lower runs first), run health probes — live, no restart.
///
/// A real table (doc 23 §10): a `label` 11/600 header, `body` 15/400 cells,
/// 48pt rows, the Bag status-pill palette and `lg` 16 gaps.
class AdminProvidersTab extends ConsumerStatefulWidget {
  const AdminProvidersTab({super.key});

  @override
  ConsumerState<AdminProvidersTab> createState() => _AdminProvidersTabState();
}

/// The width of the "priority" column.
const double _priorityColumn = 48;

/// The width of the "latency" column.
const double _latencyColumn = 72;

/// The width of the "status" column (the pill and the switch).
const double _statusColumn = 180;

class _AdminProvidersTabState extends ConsumerState<AdminProvidersTab> {
  List<ManagedProvider>? _providers;
  String? _error;
  String? _busyKey;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _error = null);
    try {
      final providers = await ref
          .read(adminProviderServiceProvider)
          .listProviders();
      if (!mounted) return;
      setState(() => _providers = providers);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _run(String key, Future<void> Function() action) async {
    setState(() => _busyKey = key);
    try {
      await action();
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Future<void> _healthCheck(String key) async {
    setState(() => _checking = true);
    try {
      await ref.read(adminProviderServiceProvider).runHealthCheck(key);
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typography = AppTypography.forLight();
    if (_error != null && _providers == null) {
      return Center(
        child: SingleChildScrollView(
          child: AppMessageState(
            icon: Icons.cloud_off_rounded,
            hue: AppColors.danger,
            title: l10n.adminError,
            body: _error ?? l10n.adminError,
            actionLabel: l10n.adminRetry,
            onAction: _reload,
          ),
        ),
      );
    }
    final providers = _providers;
    if (providers == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (providers.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: AppMessageState(
            icon: Icons.cable_rounded,
            hue: AppColors.textTertiary,
            title: l10n.adminProviders,
            body: l10n.adminNoProviders,
          ),
        ),
      );
    }

    final verticals = <String>['flight', 'hotel', 'car'];
    final labels = <String, String>{
      'flight': l10n.searchFlights,
      'hotel': l10n.searchHotels,
      'car': l10n.searchCars,
    };

    return ListView(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[
        for (final vertical in verticals) ...<Widget>[
          Text(
            labels[vertical] ?? vertical,
            style: typography.captionSemibold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _TableHeader(
            leading: l10n.adminTableProvider,
            middle: l10n.adminTablePriority,
            trailing: l10n.adminTableLatency,
            last: l10n.adminTableStatus,
          ),
          for (final provider
              in providers.where((p) => p.vertical == vertical).toList())
            _ProviderRow(
              provider: provider,
              busy: _busyKey == provider.providerKey,
              checking: _checking,
              onToggle: (value) => _run(
                provider.providerKey,
                () => ref
                    .read(adminProviderServiceProvider)
                    .setStatus(provider.providerKey, value),
              ),
              onPriorityUp: () => _run(
                provider.providerKey,
                () => ref
                    .read(adminProviderServiceProvider)
                    .setPriority(provider.providerKey, provider.priority - 1),
              ),
              onPriorityDown: () => _run(
                provider.providerKey,
                () => ref
                    .read(adminProviderServiceProvider)
                    .setPriority(provider.providerKey, provider.priority + 1),
              ),
              onHealthCheck: () => _healthCheck(provider.providerKey),
            ),
          if (providers.where((p) => p.vertical == vertical).isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
              child: Text(
                l10n.adminNoProviders,
                style: typography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

/// The table header — `label` 11/600 `textTertiary`, tracking +0.3.
class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.leading,
    required this.middle,
    required this.trailing,
    required this.last,
  });

  /// The first column's title.
  final String leading;

  /// The priority column's title.
  final String middle;

  /// The latency column's title.
  final String trailing;

  /// The status column's title.
  final String last;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final TextStyle style = typography.label.copyWith(
      color: AppColors.textTertiary,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(leading, style: style)),
          SizedBox(
            width: _priorityColumn,
            child: Text(middle, style: style),
          ),
          SizedBox(
            width: _latencyColumn,
            child: Text(trailing, style: style),
          ),
          SizedBox(
            width: _statusColumn,
            child: Text(last, style: style),
          ),
        ],
      ),
    );
  }
}

/// One provider — a 48pt record row.
class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.provider,
    required this.busy,
    required this.checking,
    required this.onToggle,
    required this.onPriorityUp,
    required this.onPriorityDown,
    required this.onHealthCheck,
  });

  final ManagedProvider provider;
  final bool busy;
  final bool checking;
  final void Function(bool value) onToggle;
  final VoidCallback onPriorityUp;
  final VoidCallback onPriorityDown;
  final VoidCallback onHealthCheck;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typography = AppTypography.forLight();

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _statusColor(),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  provider.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.body.copyWith(color: AppColors.textPrimary),
                ),
                Text(
                  provider.providerKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: _priorityColumn,
            child: Text(
              '#${provider.priority}',
              // The number keeps its reading order in Arabic ("#1", never
              // "1#").
              textDirection: TextDirection.ltr,
              style: typography.body.copyWith(color: AppColors.textPrimary),
            ),
          ),
          SizedBox(
            width: _latencyColumn,
            child: Text(
              provider.latencyMs == null ? '—' : '${provider.latencyMs} ms',
              style: typography.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: _statusColumn,
            child: Row(
              children: <Widget>[
                Flexible(child: _HealthPill(status: provider.healthStatus)),
                const Spacer(),
                Switch(
                  value: provider.isActive,
                  onChanged: busy ? null : onToggle,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: l10n.adminPriority,
            enabled: !busy,
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onSelected: (String value) {
              switch (value) {
                case 'up':
                  onPriorityUp();
                case 'down':
                  onPriorityDown();
                case 'health':
                  onHealthCheck();
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'up',
                child: Text(l10n.adminPriorityUp),
              ),
              PopupMenuItem<String>(
                value: 'down',
                child: Text(l10n.adminPriorityDown),
              ),
              PopupMenuItem<String>(
                value: 'health',
                enabled: !checking,
                child: Text(l10n.adminHealthCheck),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor() {
    if (provider.healthStatus == 'healthy') return AppColors.success;
    if (provider.healthStatus == 'unhealthy') return AppColors.danger;
    return AppColors.textTertiary;
  }
}

/// The health pill — the Bag palette (doc 22 §1.3).
class _HealthPill extends StatelessWidget {
  const _HealthPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (String label, Color fill, Color ink) = switch (status) {
      'healthy' => (
        l10n.adminHealthy,
        AppColors.successContainer,
        AppColors.onSuccessContainer,
      ),
      'unhealthy' => (
        l10n.adminUnhealthy,
        AppColors.dangerContainer,
        AppColors.danger,
      ),
      _ => (
        l10n.adminUnknown,
        AppColors.surfaceSecondary,
        AppColors.textSecondary,
      ),
    };
    return StatusChip(label: label, color: ink, container: fill);
  }
}
