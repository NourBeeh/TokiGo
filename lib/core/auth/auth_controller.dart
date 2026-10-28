import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'auth_state.dart';

/// Bridges [AuthState] to the [AuthRepository] contract.
///
/// Phase 1 keeps this thin: it restores the session state but performs no
/// business logic or real network calls.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthUnauthenticated()) {
    _restore();
  }

  final AuthRepository _repository;

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
}
