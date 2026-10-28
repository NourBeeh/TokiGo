import 'package:flutter/foundation.dart';

import '../network/api_error.dart';
import '../network/api_result.dart';
import 'user_model.dart';

/// Credentials payload for login/registration.
@immutable
class AuthCredentials {
  const AuthCredentials({required this.email, required this.password});
  final String email;
  final String password;
}

/// Registration payload.
@immutable
class RegistrationData {
  const RegistrationData({
    required this.email,
    required this.password,
    this.displayName,
  });

  final String email;
  final String password;
  final String? displayName;
}

/// Authentication contract.
///
/// Phase 1 defines the interface; no real backend exists yet.
abstract interface class AuthRepository {
  Future<ApiResult<AuthUser>> login(AuthCredentials credentials);
  Future<ApiResult<AuthUser>> register(RegistrationData data);
  Future<ApiResult<void>> logout();
  Future<ApiResult<AuthUser?>> currentSession();
}

/// A no-op, in-memory implementation used until a real backend lands.
///
/// It does not persist anything and always reports being logged out, keeping
/// the contract compile-safe without faking credentials or secrets.
class LocalAuthRepository implements AuthRepository {
  const LocalAuthRepository();

  @override
  Future<ApiResult<AuthUser>> login(AuthCredentials credentials) async {
    return const ApiResult.failure(
      ApiUnknownError(message: 'Auth backend is not yet connected (Phase 1).'),
    );
  }

  @override
  Future<ApiResult<AuthUser>> register(RegistrationData data) async {
    return const ApiResult.failure(
      ApiUnknownError(message: 'Auth backend is not yet connected (Phase 1).'),
    );
  }

  @override
  Future<ApiResult<void>> logout() async {
    return const ApiResult.success(null);
  }

  @override
  Future<ApiResult<AuthUser?>> currentSession() async {
    return const ApiResult.success(null);
  }
}
