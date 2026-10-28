/// Defensive coercion helpers shared by the AI contract parsers.
///
/// The backend `/ai/query` endpoint already normalizes its payload, but a
/// response can also reach the app from a cache, a proxy, an older backend
/// build, or a partially-written stream. These helpers guarantee that a
/// missing, null or wrong-typed field can never raise a `TypeError` while
/// parsing: every unexpected shape degrades to the documented default instead
/// of crashing the AI surface.
///
/// Mirrors the backend's `asRecord` / `asString` / `asNumber` normalization
/// helpers so both sides of the contract fail the same, predictable way.
library;

/// Returns [value] when it is a list, otherwise an empty list.
///
/// Replaces `value as List?`, which throws for `String`, `num`, `bool` and
/// `Map` payloads instead of degrading.
List<Object?> asList(Object? value) =>
    value is List ? value : const <Object?>[];

/// Returns a string-keyed copy of [value], or an empty map for any non-map.
///
/// Unlike `Map<String, dynamic>.from`, non-string keys are stringified rather
/// than triggering a cast error, so a `Map<int, dynamic>` payload degrades
/// instead of throwing.
Map<String, dynamic> asStringKeyedMap(Object? value) {
  if (value is! Map) return const <String, dynamic>{};
  if (value.isEmpty) return const <String, dynamic>{};
  final result = <String, dynamic>{};
  value.forEach((Object? key, Object? element) {
    result[key.toString()] = element;
  });
  return result;
}

/// Returns the non-null elements of [value] as strings.
///
/// Null elements are dropped rather than becoming the literal text `"null"`,
/// and a non-list payload yields an empty list.
List<String> asStringList(Object? value) {
  final raw = asList(value);
  if (raw.isEmpty) return const <String>[];
  final result = <String>[];
  for (final element in raw) {
    if (element == null) continue;
    result.add(element.toString());
  }
  return result;
}

/// Returns [value] as an `int`, or `null` when it cannot represent one.
///
/// Handles the `num` case that `int.tryParse(value.toString())` misses: a JSON
/// `1.0` stringifies to `"1.0"`, which `int.tryParse` rejects, silently
/// dropping an ordering hint. Non-finite doubles yield `null`.
int? asInt(Object? value) {
  if (value is int) return value;
  if (value is double) {
    return value.isFinite ? value.toInt() : null;
  }
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// Returns [value] as a `double`, or `null` when it cannot represent one.
double? asDouble(Object? value) {
  if (value is num) {
    final result = value.toDouble();
    return result.isFinite ? result : null;
  }
  if (value is String) {
    final result = double.tryParse(value.trim());
    return (result != null && result.isFinite) ? result : null;
  }
  return null;
}
