/// User Memory record (Phase 2A — Memory Spine Foundation).
///
/// Mirrors the backend `user_memories` contract exactly: one STRUCTURED FACT
/// (`key → value`) with provenance (`source`) and a validated `confidence`
/// (0..1). Never carries transcripts, credentials, or precise location —
/// the backend rejects those before persisting.
class MemoryRecord {
  const MemoryRecord({
    required this.id,
    required this.type,
    required this.key,
    required this.value,
    required this.source,
    required this.confidence,
    this.expiresAt,
    this.updatedAt,
  });

  factory MemoryRecord.fromMap(Map<String, dynamic> map) {
    return MemoryRecord(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      key: map['key']?.toString() ?? '',
      value: map['value'] is Map
          ? Map<String, dynamic>.from(map['value'])
          : const {},
      source: map['source']?.toString() ?? '',
      confidence: map['confidence'] is num
          ? (map['confidence'] as num).toDouble()
          : 1.0,
      expiresAt: map['expiresAt']?.toString(),
      updatedAt: map['updatedAt']?.toString(),
    );
  }

  final String id;

  /// preference | behavior | conversation | derived.
  final String type;

  /// Stable fact key, e.g. `preferred_destination`.
  final String key;

  /// Structured fact value ONLY.
  final Map<String, dynamic> value;

  /// user_explicit | behavior_event | ai_conversation | system_derived.
  final String source;

  /// 0.0 <= confidence <= 1.0 (validated server-side).
  final double confidence;

  /// ISO expiry — expired records are hidden from the default listing.
  final String? expiresAt;

  /// ISO last-update timestamp.
  final String? updatedAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'key': key,
      'value': value,
      'source': source,
      'confidence': confidence,
      if (expiresAt != null) 'expiresAt': expiresAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }
}
