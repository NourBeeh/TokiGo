import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/features/home/application/trip_draft_provider.dart';
import 'package:tokigo/l10n/app_localizations.dart';

class TripBuilderPage extends ConsumerWidget {
  const TripBuilderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final draft = ref.watch(tripDraftProvider);
    if (draft == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              AppPageHeader(title: l10n.tripBuilderTitle, subtitle: ''),
              Text(l10n.tripBuilderStartFromHome),
            ],
          ),
        ),
      );
    }
    final extras = <String, dynamic>{'city': draft.destination};
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: AppPageHeader(
                title: l10n.tripBuilderTitle,
                subtitle: draft.destination,
                trailing: IconButton(
                  tooltip: l10n.tripBuilderCancel,
                  onPressed: () {
                    ref.read(tripDraftProvider.notifier).clear();
                    context.pop();
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  l10n.tripBuilderAddProducts,
                  style: AppTypography.forLight().title.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _AddProductButton(
                      label: l10n.searchHotels,
                      icon: Icons.hotel_rounded,
                      onTap: () => context.push('/hotels', extra: extras),
                    ),
                    _AddProductButton(
                      label: l10n.searchFlights,
                      icon: Icons.flight_rounded,
                      onTap: () => context.push(
                        '/flights',
                        extra: {'destination': draft.destination},
                      ),
                    ),
                    _AddProductButton(
                      label: l10n.searchCars,
                      icon: Icons.directions_car_rounded,
                      onTap: () => context.push(
                        '/cars',
                        extra: {
                          'pickupLocation': draft.destination,
                          'dropoffLocation': draft.destination,
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Text(
                  l10n.tripBuilderSelected,
                  style: AppTypography.forLight().title.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            if (draft.items.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(l10n.tripBuilderEmpty),
                ),
              )
            else
              SliverList.builder(
                itemCount: draft.items.length,
                itemBuilder: (context, index) {
                  final item = draft.items[index];
                  return ListTile(
                    leading: Icon(switch (item.offerType) {
                      'hotel' => Icons.hotel_rounded,
                      'flight' => Icons.flight_rounded,
                      'car' => Icons.directions_car_rounded,
                      _ => Icons.luggage_rounded,
                    }),
                    title: Text(item.title ?? item.offerType),
                    subtitle: Text(item.subtitle ?? item.providerName),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.currency} ${item.price.toStringAsFixed(2)}',
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: l10n.tripBuilderRemove,
                          onPressed: () => ref
                              .read(tripDraftProvider.notifier)
                              .remove(item.offerType),
                        ),
                      ],
                    ),
                  );
                },
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xxxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.tripBuilderTotal,
                      style: AppTypography.forLight().title,
                    ),
                    ...draft.totalsByCurrency.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          '${entry.key} ${entry.value.toStringAsFixed(2)}',
                          style: AppTypography.forLight().headline.copyWith(
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                    ),
                    if (draft.items.isEmpty)
                      Text('—', style: AppTypography.forLight().headline),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.tripBuilderTotalNote,
                      style: AppTypography.forLight().caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddProductButton extends StatelessWidget {
  const _AddProductButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon),
    label: Text(label),
  );
}
