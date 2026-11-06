/// Build-time configuration for TokiGo.
///
/// Contains only non-secret, environment-agnostic values. Never place API keys,
/// credentials or secrets here (or anywhere in source).
enum AppEnvironment {
  dev('development'),
  staging('staging'),
  prod('production');

  const AppEnvironment(this.name);
  final String name;
}

class AppConfig {
  const AppConfig._();

  static const String appName = 'TokiGo';
  static const String bundleId = 'com.tokigo.tokigo';
  static const String version = '1.0.0';
  static const AppEnvironment environment = AppEnvironment.dev;

  /// Primary supported locales (left-most is fallback).
  static const List<String> supportedLocales = <String>['en', 'ar'];

  /// Semver string reflected in the About screen and diagnostics.
  static String get appVersionLabel => 'v$version';

  /// The Groups page is currently an honest empty state until group data is
  /// available; keep its route accessible from the Home shortcut.
  static const bool groupsEnabled = true;

  /// Whether the Home surface is enabled.
  ///
  /// OWNER DECISION (2026-11): Home is temporarily OFF. The app reopens on the
  /// traveller's last visited section instead, and '/' redirects to that
  /// resume target, so [HomePage] is never built and no Home feed/price call
  /// runs. The quick-action row and a "resume" button stay pinned on the
  /// service pages via the shell's top bar.
  ///
  /// Flip back to `true` to restore the current Home exactly as it was —
  /// nothing is deleted, and the resume machinery simply goes unused.
  static const bool homeEnabled = false;
}
