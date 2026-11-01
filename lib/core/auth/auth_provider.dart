import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/http_api_client.dart';
import '../storage/secure_token_storage_provider.dart';
import 'auth_controller.dart';
import 'auth_repository.dart';
import 'auth_state.dart';
import 'google_sign_in_service.dart';
import 'http_auth_repository.dart';
import 'user_model.dart';

/// Real HTTP auth repository: NestJS endpoints + OS-backed secure storage.
///
/// Tests override this provider with a fake repository; the storage and
/// client stay swappable for integration tests.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return HttpAuthRepository(
    apiClient: HttpApiClient(),
    tokenStorage: ref.watch(secureTokenStorageProvider),
  );
});

/// Google's interactive sign-in flow. Swapped for a fake in tests so no
/// platform channel is touched.
final googleSignInServiceProvider = Provider<GoogleSignInService>((ref) {
  return NativeGoogleSignInService();
});

/// Exposes the reactive [AuthState] produced by [AuthController].
///
/// Not `autoDispose`: the session must survive screen navigation so a
/// restored login is kept for the whole app lifetime.
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final repository = ref.watch(authRepositoryProvider);
    return AuthController(
      repository,
      googleSignInService: ref.watch(googleSignInServiceProvider),
    );
  },
);

/// Convenience `.user` selector for the currently authenticated user.
final authUserProvider = Provider<AuthUser?>((ref) {
  final state = ref.watch(authControllerProvider);
  return switch (state) {
    AuthAuthenticated(:final user) => user,
    _ => null,
  };
});
