/// Google Sign-In client configuration.
///
/// Only the OAuth **web** client ID is needed on the client: Android (Credential
/// Manager) and iOS request the ID token *for* that audience, and the backend
/// accepts exactly the same value (`GOOGLE_CLIENT_ID`). A client ID is a public
/// identifier — it is not a secret, unlike the client *secret*, which is never
/// used by this app because the ID token is verified server-side.
///
/// Provide it at build time:
///   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=1234-abc.apps.googleusercontent.com
///
/// or paste it into [serverClientId]'s default below for device runs.
class GoogleAuthConfig {
  const GoogleAuthConfig._();

  /// OAuth web client ID, e.g. `1234567890-abcdef.apps.googleusercontent.com`.
  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '423433597936-erj0nejep60cs5g84s4goknhis6v8jle.apps.googleusercontent.com',
  );

  /// Optional iOS OAuth client ID. On iOS, google_sign_in needs either this or
  /// a GoogleService-Info.plist. Provided via --dart-define=GOOGLE_IOS_CLIENT_ID.
  static const String iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  /// False until the ID above is supplied; the sign-in button stays hidden
  /// rather than opening a flow that cannot succeed.
  static bool get isConfigured => serverClientId.trim().isNotEmpty;
}
