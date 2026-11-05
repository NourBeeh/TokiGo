import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/geo/location_permission_providers.dart';
import 'package:tokigo/core/geo/location_permission_service.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Asks the OS for "when in use" location access and, when it is granted,
/// re-resolves the traveller's country so the departure-airport suggestion can
/// use GPS instead of the IP fallback.
///
/// A denial is NOT an error and never blocks the caller: the traveller can
/// still pick a departure airport manually later (Settings → Country). That is
/// why the first-launch intro asks here without gating the flow.
///
/// Only [LocationAccess.granted] has a side effect. `denied` / `unavailable`
/// simply leave the country to the IP fallback; `deniedForever` /
/// `serviceDisabled` are surfaced to the traveller from Settings, which owns
/// the "open the system settings" prompt.
Future<void> requestLocationAccess(WidgetRef ref) async {
  final LocationPermissionService svc = ref.read(
    locationPermissionServiceProvider,
  );
  final LocationAccess access = await svc.request();
  if (access == LocationAccess.granted) {
    ref.read(geoRefreshProvider.notifier).state++;
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
