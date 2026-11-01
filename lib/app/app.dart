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

class TokiGoApp extends ConsumerWidget {
  const TokiGoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) {
        final AppLocalizations? l10n = AppLocalizations.of(context);
        return l10n?.appTitle ?? AppConfig.appName;
      },
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
      builder: (BuildContext context, Widget? child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.systemOverlay,
          child: ListenableBuilder(
            listenable: NetworkStatus.instance,
            builder: (BuildContext context, Widget? _) {
              final MediaQueryData media = MediaQuery.of(context);
              final bool offline = !NetworkStatus.instance.online;
              return Column(
                children: <Widget>[
                  if (offline)
                    const SafeArea(bottom: false, child: OfflineBanner()),
                  Expanded(
                    child: MediaQuery(
                      data: media.copyWith(
                        padding: media.padding.copyWith(
                          top: offline ? 0 : media.padding.top,
                        ),
                      ),
                      child: ScrollConfiguration(
                        behavior: const _SmoothScrollBehavior(),
                        child: child ?? const SizedBox.shrink(),
                      ),
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

class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
