import 'package:flutter/foundation.dart';

@immutable
class Token {
  const Token({
    required this.value,
    required this.expiresAt,
    this.type = 'Bearer',
  });

  final String value;
  final DateTime expiresAt;
  final String type;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
