import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/auth/session_model.dart';
import 'package:tokigo/core/auth/token_model.dart';
import 'package:tokigo/core/auth/user_model.dart';

void main() {
  test('Session isExpired works', () {
    final user = const AuthUser(id: '1', email: 'a@b.com');
    final token = Token(value: 't', expiresAt: DateTime(2000));
    final session = Session(
      user: user,
      accessToken: token,
      refreshToken: token,
      expiresAt: DateTime(2000),
    );
    expect(session.isExpired, true);
  });

  test('Token isExpired works', () {
    final token = Token(value: 't', expiresAt: DateTime(2000));
    expect(token.isExpired, true);
  });
}
