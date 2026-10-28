import 'package:flutter/foundation.dart';

import 'ai_parsing.dart';

/// Future action metadata carried by an AI card/item.
///
/// Purely a contract: typed, safe payload a later tap handler can turn into
/// navigation/booking calls without touching the HomeCard engine today.
@immutable
class AiAction {
  const AiAction({required this.type, this.label, this.payload = const {}});

  /// Kind of action, e.g. `book`, `view`, `open`, `call`.
  final String type;

  /// Human-friendly label shown to the user, when provided.
  final String? label;

  /// Opaque, action-specific arguments (offer id, deep link, query...).
  final Map<String, dynamic> payload;

  factory AiAction.fromMap(Map<String, dynamic> map) {
    return AiAction(
      type: map['type']?.toString() ?? '',
      label: map['label']?.toString(),
      payload: asStringKeyedMap(map['payload']),
    );
  }
}
