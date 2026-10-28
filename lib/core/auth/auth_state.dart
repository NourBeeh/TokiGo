import 'package:flutter/foundation.dart';

import 'user_model.dart';

/// Immutable authentication state machine.
///
/// Phase 1 only installs the state shapes; no business logic drives them yet.
@immutable
sealed class AuthState {
  const AuthState(this.user);
  final AuthUser? user;

  bool get isAuthenticated => user != null;
  bool get isAnonymous => !isAuthenticated;
}

/// No known session.
@immutable
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated() : super(null);
}

/// A sign-in is in progress (login/registration).
@immutable
class AuthLoading extends AuthState {
  const AuthLoading([super.user]);
}

/// A session is active.
@immutable
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(super.user);
}

/// A previous session failed to restore.
@immutable
class AuthError extends AuthState {
  const AuthError(this.error, [super.user]);
  final Object error;
}
