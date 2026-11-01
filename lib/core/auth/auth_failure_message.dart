import '../network/api_error.dart';
import '../network/user_facing_message.dart';

/// Which sign-in control produced a failure, so the message can be specific
/// without inventing a new error type per flow.
enum AuthAction { password, google }

/// Maps an auth failure to a message that is safe to show.
///
/// Delegates the generic cases to [userFacingMessage] (the app-wide boundary
/// that never prints backend or transport text) and only refines the two cases
/// that are actively misleading otherwise:
///
/// - `401` on a password sign-in is a wrong password, not an expired session.
/// - `409` on Google is an account that already has a password — the backend
///   refuses to attach Google to it, and the user needs to hear that.
String authFailureMessage(Object error, {AuthAction action = AuthAction.password}) {
  final bool viaGoogle = action == AuthAction.google;

  if (error is ApiUnauthorizedError) {
    return viaGoogle
        ? 'Google could not confirm this account. Please try again.'
        : 'Incorrect email or password.';
  }

  if (viaGoogle &&
      error is ApiClientError &&
      error.statusCode == 409) {
    return 'This email already has a password sign-in. Sign in with your password.';
  }

  if (viaGoogle && error is ApiUnknownError) {
    // Raised when the platform flow itself could not run (unsupported, not
    // configured, or the Google SDK refused the request).
    return 'Google sign-in is unavailable right now. Please use your email instead.';
  }

  return userFacingMessage(error, subject: 'sign in');
}
