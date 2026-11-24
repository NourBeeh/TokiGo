import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/geo/city_providers.dart';
import 'package:tokigo/core/geo/city_selection.dart';
import 'package:tokigo/core/geo/location_permission_providers.dart';
import 'package:tokigo/core/geo/location_permission_service.dart';
import 'package:tokigo/core/geo/location_prompt.dart';
import 'package:tokigo/core/geo/location_prompt_controller.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// A neutral, dismissible Home card that explains why location helps.
///
/// Rules:
///  * it never appears when permission is already granted, when the platform
///    cannot answer, or when a manual city already exists;
///  * it is shown at most twice and a dismissal silences it for 14 days
///    (see [LocationPromptController]);
///  * denying it never blocks anything — City Selection always works;
///  * a permanent denial / disabled service offers Open Settings instead of a
///    dead "Enable" button.
class LocationPermissionCard extends ConsumerStatefulWidget {
  const LocationPermissionCard({super.key});

  @override
  ConsumerState<LocationPermissionCard> createState() =>
      _LocationPermissionCardState();
}

class _LocationPermissionCardState
    extends ConsumerState<LocationPermissionCard>
    with WidgetsBindingObserver {
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The permission can change while the app is backgrounded — the traveller
    // leaves for the OS settings screen and grants access. `locationAccess`
    // is a cached FutureProvider, so without this refresh the card would keep
    // showing "Enable location" until the next app launch.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(locationAccessProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<LocationAccess> accessAsync =
        ref.watch(locationAccessProvider);
    final LocationAccess? access = accessAsync.asData?.value;
    final bool hasManualCity = ref.watch(hasManualCityProvider);
    // Watch the persisted prompt state so a dismissal or impression change
    // rebuilds visibility immediately.
    ref.watch(locationPromptControllerProvider);
    final bool mayShow = ref
        .read(locationPromptControllerProvider.notifier)
        .mayShow();

    final bool visible =
        !hasManualCity &&
        access != null &&
        access != LocationAccess.granted &&
        access != LocationAccess.unavailable &&
        mayShow;

    if (!visible) {
      _recorded = false;
      return const SizedBox.shrink();
    }
    if (!_recorded) {
      _recorded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(locationPromptControllerProvider.notifier).recordImpression();
      });
    }

    final l10n = AppLocalizations.of(context)!;
    final bool canAsk = access == LocationAccess.denied;
    final String body = access == LocationAccess.serviceDisabled
        ? l10n.locationCardServicesOff
        : l10n.locationCardBody;

    return Semantics(
      container: true,
      label: l10n.locationCardTitle,
      child: Container(
        margin: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.tokigoColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: context.tokigoColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.near_me_outlined,
                  size: 20,
                  color: context.tokigoColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.locationCardTitle,
                    style: _bodyStyle(context).copyWith(
                      color: context.tokigoColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: AppSpacing.xl),
              child: Text(
                body,
                style: _captionStyle(context).copyWith(
                  color: context.tokigoColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => ref
                      .read(locationPromptControllerProvider.notifier)
                      .dismiss(),
                  child: Text(l10n.locationCardNotNow),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton(
                  onPressed: () => canAsk
                      ? _enable(context, ref)
                      : _openSettings(context, ref, access),
                  child: Text(
                    canAsk
                        ? l10n.locationCardEnable
                        : l10n.locationCardOpenSettings,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    final LocationPermissionService service = ref.read(
      locationPermissionServiceProvider,
    );
    final LocationAccess result = await service.request();
    ref.invalidate(locationAccessProvider);
    if (result == LocationAccess.granted) {
      ref.read(geoRefreshProvider.notifier).state++;
      await ref
          .read(cityDetectionServiceProvider)
          .detectIfNeeded(force: true);
      return;
    }
    if (!context.mounted) return;
    if (result == LocationAccess.deniedForever) {
      await showLocationSettingsPrompt(context, ref, serviceOff: false);
    } else if (result == LocationAccess.serviceDisabled) {
      await showLocationSettingsPrompt(context, ref, serviceOff: true);
    }
  }

  Future<void> _openSettings(
    BuildContext context,
    WidgetRef ref,
    LocationAccess? access,
  ) async {
    await showLocationSettingsPrompt(
      context,
      ref,
      serviceOff: access == LocationAccess.serviceDisabled,
    );
    ref.invalidate(locationAccessProvider);
  }

  static TextStyle _bodyStyle(BuildContext context) =>
      (Theme.of(context).brightness == Brightness.dark
              ? AppTypography.forDark()
              : AppTypography.forLight())
          .body;

  static TextStyle _captionStyle(BuildContext context) =>
      (Theme.of(context).brightness == Brightness.dark
              ? AppTypography.forDark()
              : AppTypography.forLight())
          .caption;
}
