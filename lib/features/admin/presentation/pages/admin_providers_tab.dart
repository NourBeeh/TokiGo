import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/admin/admin_provider_models.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import '../admin_services.dart';

/// API provider management (ADM-A2 + ADM-B1): toggle activity per vertical,
/// reorder priority (lower runs first), run health probes — live, no restart.
class AdminProvidersTab extends ConsumerStatefulWidget {
  const AdminProvidersTab({super.key});

  @override
  ConsumerState<AdminProvidersTab> createState() =>
      _AdminProvidersTabState();
}

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
      final providers =
          await ref.read(adminProviderServiceProvider).listProviders();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(l10n.adminError, style: typography.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: _reload, child: Text(l10n.adminRetry)),
          ],
        ),
      );
    }
    final providers = _providers;
    if (providers == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final verticals = <String>['flight', 'hotel', 'car'];
    final labels = <String, String>{
      'flight': l10n.searchFlights,
      'hotel': l10n.searchHotels,
      'car': l10n.searchCars,
    };

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        for (final vertical in verticals) ...<Widget>[
          Text(
            labels[vertical] ?? vertical,
            style: typography.bodyLargeMedium
                .copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final provider in providers
              .where((p) => p.vertical == vertical)
              .toList())
            _ProviderTile(
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
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
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
    final healthy = provider.healthStatus == 'healthy';
    final unhealthy = provider.healthStatus == 'unhealthy';
    final statusColor = healthy
        ? AppColors.success
        : unhealthy
            ? AppColors.danger
            : AppColors.textTertiary;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: provider.isActive ? AppColors.outline : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      provider.name,
                      style: typography.bodyLargeMedium
                          .copyWith(color: AppColors.textPrimary),
                    ),
                    Text(
                      '${provider.providerKey} · #${provider.priority}'
                      '${provider.isFallback ? ' · fallback' : ''}',
                      style: typography.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                l10n.adminActive,
                style: typography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              Switch(
                value: provider.isActive,
                onChanged: busy ? null : onToggle,
              ),
            ],
          ),
          Row(
            children: <Widget>[
              IconButton(
                tooltip: l10n.adminPriority,
                onPressed: busy ? null : onPriorityUp,
                icon: const Icon(Icons.arrow_upward_rounded, size: 20),
              ),
              IconButton(
                tooltip: l10n.adminPriority,
                onPressed: busy ? null : onPriorityDown,
                icon: const Icon(Icons.arrow_downward_rounded, size: 20),
              ),
              const Spacer(),
              if (provider.latencyMs != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: Text(
                    '${l10n.adminLatency}: ${provider.latencyMs}ms',
                    style: typography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              TextButton.icon(
                onPressed: busy || checking ? null : onHealthCheck,
                icon: checking && busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.monitor_heart_outlined, size: 18),
                label: Text(l10n.adminHealthCheck),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
