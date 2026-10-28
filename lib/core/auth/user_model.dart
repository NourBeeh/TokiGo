import 'package:flutter/foundation.dart';

/// Authenticated user model used across the whole app.
///
/// Immutable, JSON-serialisable. Extended in later phases (profile, trips,
/// preferences) without breaking the core contract.
@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.phoneNumber,
    this.role = 'user',
  });

  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String? phoneNumber;

  /// Backend role (Phase-17 users table). 'admin' unlocks the admin panel.
  final String role;

  bool get isAdmin => role == 'admin';

  bool get isAnonymous => id.isEmpty;

  AuthUser copyWith({
    String? id,
    String? email,
    String? displayName,
    bool clearDisplayName = false,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    String? phoneNumber,
    bool clearPhoneNumber = false,
    String? role,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: clearDisplayName ? null : displayName ?? this.displayName,
      avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
      phoneNumber: clearPhoneNumber ? null : phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
    );
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      role: json['role'] as String? ?? 'user',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'email': email,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'phoneNumber': phoneNumber,
    'role': role,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          other.id == id &&
          other.email == email &&
          other.displayName == displayName &&
          other.avatarUrl == avatarUrl &&
          other.phoneNumber == phoneNumber;

  @override
  int get hashCode =>
      Object.hash(id, email, displayName, avatarUrl, phoneNumber);

  @override
  String toString() => 'AuthUser(id: $id, email: $email)';
}
