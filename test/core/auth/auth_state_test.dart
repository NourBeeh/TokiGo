import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/auth/auth_repository.dart';
import 'package:tokigo/core/auth/auth_state.dart';
import 'package:tokigo/core/auth/user_model.dart';

void main() {
  group('AuthState', () {
    test('Unauthenticated is not authenticated', () {
      const state = AuthUnauthenticated();
      expect(state.isAuthenticated, isFalse);
      expect(state.user, isNull);
    });

    test('Authenticated wraps a user', () {
      const user = AuthUser(id: '1', email: 'a@b.com');
      const state = AuthAuthenticated(user);
      expect(state.isAuthenticated, isTrue);
      expect(state.user, user);
    });
  });

  group('AuthRepository contract', () {
    test('LocalAuthRepository.login is not wired yet', () async {
      const repo = LocalAuthRepository();
      final result = await repo.login(
        const AuthCredentials(email: 'a@b.com', password: 'secret'),
      );
      expect(result.isFailure, isTrue);
    });
  });
}