import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/network_status.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/offline_banner.dart';
import '../l10n/app_localizations.dart';
import 'config/app_config.dart';
import 'router/go_router_config.dart';
import '../shared/providers/locale_provider.dart';

/// Root widget for TokiGo.
///
/// Mounts the light-only "Pure White Premium" theme, the en/ar localization
/// delegates, and the go-router shell. Riverpod is provided above this widget
/// in `main.dart`.
class TokiGoApp extends ConsumerWidget {
  const TokiGoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Edge-to-edge (enforced from targetSdk 35): the only place the system
      // bars' contrast is decided for the whole app, since every page draws its
      // own header instead of an AppBar.
      builder: (BuildContext context, Widget? child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.systemOverlay,
          // The offline strip lives ABOVE the router, so every page shows it —
          // and only when the backend really could not be reached.
          child: ListenableBuilder(
            listenable: NetworkStatus.instance,
            // NOTE: the inner parameter is NOT named `child` — that would
            // shadow the router's child and leave the app with nothing to
            // draw.
            builder: (BuildContext context, Widget? _) {
              final MediaQueryData media = MediaQuery.of(context);
              final bool offline = !NetworkStatus.instance.online;
              return Column(
                children: <Widget>[
                  if (offline)
                    const SafeArea(bottom: false, child: OfflineBanner()),
                  Expanded(
                    child: MediaQuery(
                      // The banner already cleared the status bar, so the
                      // pages must not pad for it a second time.
                      data: media.copyWith(
                        padding: media.padding.copyWith(
                          top: offline ? 0 : media.padding.top,
                        ),
                      ),
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
      routerConfig: router,
    );
  }
}
