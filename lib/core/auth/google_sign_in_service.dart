import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_auth_config.dart';

/// Why a Google sign-in attempt could not be started or completed.
///
/// The reasons are for diagnostics only — the UI shows a fixed message, never
/// this text, so platform detail never reaches the screen.
enum GoogleSignInFailure {
  /// The platform has no supported interactive flow (e.g. web, which requires
  /// a button rendered by Google's own SDK).
  unsupportedPlatform,

  /// `GOOGLE_SERVER_CLIENT_ID` was not supplied at build time.
  missingConfiguration,

  /// The Google SDK refused the request (missing SHA-1 / package name, no
  /// network, SDK unavailable, or no ID token returned).
  failed,
}

class GoogleSignInUnavailableException implements Exception {
  const GoogleSignInUnavailableException(this.failure);

  final GoogleSignInFailure failure;

  @override
  String toString() => 'GoogleSignInUnavailableException($failure)';
}

/// Runs Google's interactive sign-in flow and returns an ID token.
abstract interface class GoogleSignInService {
  /// Returns a Google-issued OIDC ID token, or `null` when the user dismissed
  /// the account picker (a cancel is not an error).
  ///
  /// Throws [GoogleSignInUnavailableException] when the flow cannot be used.
  Future<String?> idToken();
}

/// [GoogleSignInService] backed by the `google_sign_in` plugin.
class NativeGoogleSignInService implements GoogleSignInService {
  bool _initialized = false;

  @override
  Future<String?> idToken() async {
    final GoogleSignIn signIn = GoogleSignIn.instance;

    if (!signIn.supportsAuthenticate()) {
      throw const GoogleSignInUnavailableException(
        GoogleSignInFailure.unsupportedPlatform,
      );
    }
    if (!GoogleAuthConfig.isConfigured) {
      throw const GoogleSignInUnavailableException(
        GoogleSignInFailure.missingConfiguration,
      );
    }

    if (!_initialized) {
      // Must complete before any other call on the instance. On Android the web
      // client ID is the `serverClientId`: it is the audience the returned ID
      // token is minted for, and the value the backend validates against.
      await signIn.initialize(
        serverClientId: GoogleAuthConfig.serverClientId,
        clientId: kIsWeb
            ? GoogleAuthConfig.serverClientId
            : (defaultTargetPlatform == TargetPlatform.iOS &&
                    GoogleAuthConfig.iosClientId.isNotEmpty
                ? GoogleAuthConfig.iosClientId
                : null),
      );
      _initialized = true;
    }

    final GoogleSignInAccount account;
    try {
      account = await signIn.authenticate();
    } on GoogleSignInException catch (error) {
      // Always log the original code/message; config errors often surface as
      // 'canceled', which is otherwise indistinguishable from a real cancel.
      debugPrint('GoogleSignIn failed: code=${error.code} desc=${error.description}');
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      throw const GoogleSignInUnavailableException(GoogleSignInFailure.failed);
    }

    final String? token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      // Without an ID token there is nothing for the backend to verify.
      throw const GoogleSignInUnavailableException(GoogleSignInFailure.failed);
    }
    return token;
  }
}
