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
}