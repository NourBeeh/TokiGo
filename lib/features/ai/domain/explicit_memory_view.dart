import 'package:flutter/foundation.dart';

import 'package:tokigo/core/memory/memory_model.dart';

/// 2C-C2 — Explicit conversation memory presentation model.
///
/// Wraps a Phase 2A [MemoryRecord] of the STRICT 2C vocabulary
/// (preferred_destination / preferred_budget / preferred_travel_style) in a
/// view-friendly, human-readable shape. The UI NEVER renders raw database
/// fields — only [title] / [subtitle] / [displayValue] produced here, and the
/// editor validates against the SAME limits the backend enforces
/// (conversation_facts.ts): destination ≤ 80 chars, styles ≤ 60 items × 60
/// chars each, budget min/max finite numbers with min ≤ max.
@immutable
class ExplicitMemoryView {
  const ExplicitMemoryView({required this.record, required this.kind});

  /// Allowed explicit conversation memory kinds (2C decision — nothing
  /// outside this vocabulary may be created or edited).
  static const List<String> allowedKinds = <String>[
    'preferred_destination',
    'preferred_budget',
    'preferred_travel_style',
  ];

  /// The raw Phase 2A record. Kept private in spirit: the UI renders only
  /// the derived fields below, never the record's internals.
  final MemoryRecord record;

  /// One of [allowedKinds] — guaranteed by [fromRecord]'s filter.
  final String kind;

  /// Maps a conversation memory record into a view, or `null` when the
  /// record is NOT part of the strict 2C vocabulary (behavioral/derived/
  /// other rows are invisible to this surface by design).
  static ExplicitMemoryView? fromRecord(MemoryRecord record) {
    final kind = _baseKindOf(record.key);
    if (kind == null) return null;
    if (record.type != 'conversation' && record.type != 'preference') {
      return null;
    }
    return ExplicitMemoryView(record: record, kind: kind);
  }

  /// `preferred_destination:paris` → `preferred_destination`.
  static String? _baseKindOf(String key) {
    final base = key.split(':').first;
    return allowedKinds.contains(base) ? base : null;
  }

  /// Human-readable group title for the kind (kept in English — the page
  /// itself localizes through l10n keys; this is the stable group label).
  String get title {
    return switch (kind) {
      'preferred_destination' => 'Preferred destination',
      'preferred_budget' => 'Preferred budget',
      _ => 'Preferred travel style',
    };
  }

  /// Human-readable one-line rendering of the VALUE only — never the raw
  /// JSON object, never the record id/source/confidence.
  String get displayValue {
    final value = record.value;
    return switch (kind) {
      'preferred_destination' => value['destination']?.toString() ?? '',
      'preferred_budget' => _formatBudget(value),
      _ => _formatStyles(value),
    };
  }

  static String _formatBudget(Map<String, dynamic> value) {
    final min = value['min'];
    final max = value['max'];
    final hasMin = min is num;
    final hasMax = max is num;
    if (hasMin && hasMax) {
      return '${_num(min)} – ${_num(max)}';
    }
    if (hasMin) return 'From ${_num(min)}';
    if (hasMax) return 'Up to ${_num(max)}';
    return '';
  }

  static String _num(num n) {
    final d = n.toDouble();
    return d == d.roundToDouble() ? d.round().toString() : d.toString();
  }

  static String _formatStyles(Map<String, dynamic> value) {
    final raw = value['styles'];
    if (raw is! List) return '';
    return raw.map((e) => e.toString()).join(', ');
  }
}

/// 2C-C2 — Validation + normalization for memory edits, mirroring the
/// backend `conversation_facts.ts` limits exactly so an invalid value fails
/// on the device BEFORE any network call.
@immutable
class ExplicitMemoryInput {
  const ExplicitMemoryInput({required this.kind, required this.value});

  final String kind;
  final Map<String, dynamic> value;

  /// Mirrors CONVERSATION_FACT_LIMITS (backend/src/modules/memory/
  /// conversation_facts.ts).
  static const int destinationMaxChars = 80;
  static const int stylesMaxItems = 60;
  static const int styleMaxChars = 60;

  /// Validates + normalizes raw editor input for [kind].
  ///
  /// Returns an error message when the input violates the vocabulary
  /// contract, or `null` when it is safe to send. Pure and total — never
  /// throws. [destination] is trimmed; [styles] is split on comma/Arabic
  /// comma, trimmed, and empty entries dropped; [min]/[max] must parse as
  /// finite numbers when provided and min ≤ max.
  static String? validate({
    required String kind,
    String? destination,
    String? minBudget,
    String? maxBudget,
    String? styles,
  }) {
    switch (kind) {
      case 'preferred_destination':
        final trimmed = (destination ?? '').trim();
        if (trimmed.isEmpty) {
          return 'Destination cannot be empty.';
        }
        if (trimmed.length > destinationMaxChars) {
          return 'Destination must be at most $destinationMaxChars characters.';
        }
        return null;
      case 'preferred_budget':
        double? min;
        double? max;
        if ((minBudget ?? '').trim().isNotEmpty) {
          min = double.tryParse(minBudget!.trim());
          if (min == null) return 'Minimum budget must be a number.';
        }
        if ((maxBudget ?? '').trim().isNotEmpty) {
          max = double.tryParse(maxBudget!.trim());
          if (max == null) return 'Maximum budget must be a number.';
        }
        if (min == null && max == null) {
          return 'Enter at least one budget bound.';
        }
        if (min != null && max != null && min > max) {
          return 'Minimum budget cannot exceed the maximum.';
        }
        return null;
      case 'preferred_travel_style':
        final items = _splitStyles(styles);
        if (items.isEmpty) {
          return 'Add at least one travel style.';
        }
        if (items.length > stylesMaxItems) {
          return 'At most $stylesMaxItems styles are allowed.';
        }
        if (items.any((s) => s.length > styleMaxChars)) {
          return 'Each style must be at most $styleMaxChars characters.';
        }
        return null;
      default:
        return 'Unknown memory type.';
    }
  }

  /// Builds the structured value map for a VALIDATED input (call
  /// [validate] first — this performs no checks beyond trimming).
  static Map<String, dynamic> buildValue({
    required String kind,
    String? destination,
    String? minBudget,
    String? maxBudget,
    String? styles,
  }) {
    return switch (kind) {
      'preferred_destination' => <String, dynamic>{
          'destination': (destination ?? '').trim(),
        },
      'preferred_budget' => <String, dynamic>{
          if ((minBudget ?? '').trim().isNotEmpty)
            'min': double.parse(minBudget!.trim()),
          if ((maxBudget ?? '').trim().isNotEmpty)
            'max': double.parse(maxBudget!.trim()),
        },
      _ => <String, dynamic>{'styles': _splitStyles(styles)},
    };
  }

  static List<String> _splitStyles(String? styles) {
    if (styles == null) return const <String>[];
    return styles
        .split(RegExp(r'[,،]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
