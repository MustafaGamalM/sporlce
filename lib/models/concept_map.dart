class ConceptMap {
  const ConceptMap({
    required this.language,
    required this.concepts,
    required this.relationships,
    required this.image,
  });

  factory ConceptMap.fromJson(Map<String, dynamic> json) {
    final conceptsJson = json['concepts'] as List<dynamic>? ?? const [];
    final relationshipsJson =
        json['relationships'] as List<dynamic>? ?? const [];
    final imageJson = json['image'];

    return ConceptMap(
      language: json['language'] as String? ?? 'en',
      concepts: conceptsJson
          .whereType<Map<String, dynamic>>()
          .map(Concept.fromJson)
          .toList(),
      relationships: relationshipsJson
          .whereType<Map<String, dynamic>>()
          .map(ConceptRelationship.fromJson)
          .toList(),
      image: imageJson is Map<String, dynamic>
          ? ConceptMapImage.fromJson(imageJson)
          : const ConceptMapImage(url: '', format: 'svg'),
    );
  }

  final String language;
  final List<Concept> concepts;
  final List<ConceptRelationship> relationships;
  final ConceptMapImage image;
}

class Concept {
  const Concept({required this.id, required this.label});

  factory Concept.fromJson(Map<String, dynamic> json) {
    return Concept(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }

  final String id;
  final String label;
}

class ConceptRelationship {
  const ConceptRelationship({
    required this.from,
    required this.to,
    required this.type,
  });

  factory ConceptRelationship.fromJson(Map<String, dynamic> json) {
    return ConceptRelationship(
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      type: json['type'] as String? ?? '',
    );
  }

  final String from;
  final String to;
  final String type;
}

class ConceptMapImage {
  const ConceptMapImage({required this.url, required this.format});

  factory ConceptMapImage.fromJson(Map<String, dynamic> json) {
    return ConceptMapImage(
      url: json['url'] as String? ?? '',
      format: json['format'] as String? ?? 'svg',
    );
  }

  final String url;
  final String format;
}

class GenerateConceptMapRequest {
  const GenerateConceptMapRequest({
    required this.text,
    required this.language,
    required this.maxConcepts,
    required this.format,
    required this.hierarchical,
  });

  final String text;
  final String language;
  final int maxConcepts;
  final String format;
  final bool hierarchical;

  Map<String, Object> toJson() {
    return {
      'language': language,
      'max_concepts': maxConcepts.toString(),
      'format': format,
      'hierarchical': hierarchical,
      'text': text,
    };
  }
}
