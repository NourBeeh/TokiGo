import 'package:flutter/foundation.dart';

import 'ai_parsing.dart';
import 'ai_section.dart';

/// Top-level contract for an AI assistant response.
///
/// Pure data — no providers, no transport. A later phase parses a backend
/// payload into this shape (or renders it directly through a controller), and
/// the AI surface shows [text] plus the ordered [sections] using the existing
/// HomeCard engine via a small mapper at the boundary.
@immutable
class AiResponse {
  const AiResponse({
    this.text,
    this.sections = const [],
    this.metadata = const {},
  });

  /// Natural-language content — e.g. "وجدت لك 3 فنادق مناسبة".
  /// Accepts both `text` and `content` payload keys on parse.
  final String? text;

  /// Ordered semantic blocks; each becomes a section on the AI surface.
  final List<AiSection> sections;

  /// Response-level metadata (query id, model, latency...).
  final Map<String, dynamic> metadata;

  factory AiResponse.fromMap(Map<String, dynamic> map) {
    final sections = <AiSection>[];
    for (final entry in asList(map['sections'])) {
      // Accept any map shape: a payload decoded outside `jsonDecode` can carry
      // `Map<dynamic, dynamic>` entries, which a `Map<String, dynamic>` test
      // would silently drop.
      if (entry is Map) {
        sections.add(AiSection.fromMap(asStringKeyedMap(entry)));
      }
    }
    return AiResponse(
      text: map['text']?.toString() ?? map['content']?.toString(),
      sections: sections,
      metadata: asStringKeyedMap(map['metadata']),
    );
  }
}
