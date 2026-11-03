import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/geo/location_permission_providers.dart';
import 'package:tokigo/core/geo/location_permission_service.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/pressable.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Asks for location from an EXPLICIT user tap and routes the outcome:
/// granted → re-resolve the country with GPS; blocked/service-off → an
/// in-app prompt that opens the right system settings; declined → nothing
/// (the caller keeps its explainer so the traveller can try again).
Future<void> requestLocationAccess(BuildContext context, WidgetRef ref) async {
  final svc = ref.read(locationPermissionServiceProvider);
  final access = await svc.request();
  if (!context.mounted) return;

  switch (access) {
    case LocationAccess.granted:
      ref.read(geoRefreshProvider.notifier).state++;
      ref.invalidate(locationAccessProvider);
    case LocationAccess.deniedForever:
      await showLocationSettingsPrompt(context, ref, serviceOff: false);
    case LocationAccess.serviceDisabled:
      await showLocationSettingsPrompt(context, ref, serviceOff: true);
    case LocationAccess.denied:
    case LocationAccess.unavailable:
      // Not a permanent answer: refresh the (non-prompting) state so the
      // explainer reflects reality, and leave the choice to the traveller.
      ref.invalidate(locationAccessProvider);
  }
}

/// The "you blocked location / services are off" prompt with a button that
/// opens the OS settings that can actually unblock it.
Future<void> showLocationSettingsPrompt(
  BuildContext context,
  WidgetRef ref, {
  required bool serviceOff,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final title = serviceOff
      ? l10n.locationPromptServiceOffTitle
      : l10n.locationPromptBlockedTitle;
  final body = serviceOff
      ? l10n.locationPromptServiceOffBody
      : l10n.locationPromptBlockedBody;
  final action = serviceOff
      ? l10n.locationPromptLocationSettings
      : l10n.locationPromptOpenSettings;

  final bool? open = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.locationPromptNotNow),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  if (open != true || !context.mounted) return;

  final svc = ref.read(locationPermissionServiceProvider);
  if (serviceOff) {
    await svc.openLocationSettings();
  } else {
    await svc.openSettings();
  }
  ref.invalidate(locationAccessProvider);
}

/// Dismissible, in-context explainer shown on Home when location is not yet
/// granted. The OS dialog is raised ONLY from the "Allow" tap — never on
/// launch — and dismissing the card is session-scoped (a refusal is not a
/// permanent preference).
class LocationPermissionCard extends ConsumerWidget {
  const LocationPermissionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Never show on platforms/tests that cannot answer the permission query,
    // and never once access is granted.
    final LocationAccess access = ref
        .watch(locationAccessProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => LocationAccess.unavailable,
        );
    if (access == LocationAccess.granted ||
        access == LocationAccess.unavailable ||
        ref.watch(locationPromptDismissedProvider)) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final typography = AppTypography.forLight();
    final tc = context.tokigoColors;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: tc.surfaceSecondary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: tc.hairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.location_on_rounded, size: 22, color: tc.brand),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.locationPromptTitle,
                    style: typography.bodyLargeMedium.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    l10n.locationPromptBody,
                    style: typography.caption.copyWith(
                      color: tc.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      Pressable.wrap(
                        child: TextButton(
                          onPressed: () => ref
                              .read(locationPromptDismissedProvider.notifier)
                              .state = true,
                          child: Text(l10n.locationPromptNotNow),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Pressable.wrap(
                        child: TextButton(
                          onPressed: () => requestLocationAccess(context, ref),
                          child: Text(l10n.locationPromptAllow),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
