import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_error.dart';
import 'auth_repository.dart';
import 'auth_state.dart';
import 'google_sign_in_service.dart';
import 'user_model.dart';

/// Bridges [AuthState] to the [AuthRepository] contract.
///
/// Phase 1 keeps this thin: it restores the session state but performs no
/// business logic or real network calls.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository, {GoogleSignInService? googleSignInService})
    : _googleSignInService =
          googleSignInService ?? NativeGoogleSignInService(),
      super(const AuthUnauthenticated()) {
    _restore();
  }

  final AuthRepository _repository;
  final GoogleSignInService _googleSignInService;

  Future<void> _restore() async {
    final result = await _repository.currentSession();
    final user = result.valueOrNull;
    if (user == null) {
      state = const AuthUnauthenticated();
    } else {
      state = AuthAuthenticated(user);
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = AuthLoading(state.user);
    final result = await _repository.login(
      AuthCredentials(email: email, password: password),
    );
    state = result.when(
      success: (user) => AuthAuthenticated(user),
      failure: (error) => AuthError(error, state.user),
    );
  }

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = AuthLoading(state.user);
    final result = await _repository.register(
      RegistrationData(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
    state = result.when(
      success: (user) => AuthAuthenticated(user),
      failure: (error) => AuthError(error, state.user),
    );
  }

  Future<void> logout() async {
    state = AuthLoading(state.user);
    await _repository.logout();
    state = const AuthUnauthenticated();
  }

  Future<void> updateProfile(AuthUser user) async {
    final result = await _repository.updateProfile(user);
    final updated = result.valueOrNull ?? user;
    state = AuthAuthenticated(updated);
  }

  /// Google sign-in: the platform SDK yields an ID token, which is exchanged
  /// for our own session. Dismissing the account picker is not an error — the
  /// previous state is simply restored.
  Future<void> signInWithGoogle() async {
    final AuthUser? previous = state.user;
    state = AuthLoading(previous);

    final String? idToken;
    try {
      idToken = await _googleSignInService.idToken();
    } catch (error) {
      // Platform/config failures carry no credentials; keep the detail for
      // diagnostics and let the UI show a fixed message.
      state = AuthError(ApiUnknownError(message: error.toString()), previous);
      return;
    }

    if (idToken == null) {
      state = previous == null
          ? const AuthUnauthenticated()
          : AuthAuthenticated(previous);
      return;
    }

    final result = await _repository.signInWithGoogle(idToken);
    state = result.when(
      success: (user) => AuthAuthenticated(user),
      failure: (error) => AuthError(error, previous),
    );
  }
}
