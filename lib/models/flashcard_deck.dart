import 'package:sporcle/models/json_helpers.dart';

class FlashcardDeck {
  const FlashcardDeck({
    required this.language,
    required this.count,
    required this.cards,
    this.note,
  });

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) {
    final cardsJson = json['cards'] as List<dynamic>? ?? const [];

    return FlashcardDeck(
      language: json['language'] as String? ?? 'ar',
      count: jsonInt(json['count'], fallback: cardsJson.length),
      cards: cardsJson
          .whereType<Map<String, dynamic>>()
          .map(Flashcard.fromJson)
          .toList(),
      note: json['note'] as String?,
    );
  }

  final String language;
  final int count;
  final List<Flashcard> cards;
  final String? note;
}

class Flashcard {
  const Flashcard({
    required this.type,
    required this.front,
    required this.back,
    this.hint,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      type: json['type'] as String? ?? 'basic',
      front: json['front'] as String? ?? '',
      back: json['back'] as String? ?? '',
      hint: json['hint'] as String?,
    );
  }

  final String type;
  final String front;
  final String back;
  final String? hint;

  bool get isCloze => type == 'cloze';
}

class GenerateFlashcardsRequest {
  const GenerateFlashcardsRequest({
    required this.text,
    required this.language,
    required this.numCards,
  });

  final String text;
  final String language;
  final int numCards;

  Map<String, Object> toJson() {
    return {'text': text, 'language': language, 'num_cards': numCards};
  }
}
