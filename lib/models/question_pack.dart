import 'dart:convert';

import 'package:sporcle/models/json_helpers.dart';

class QuestionPack {
  const QuestionPack({
    required this.id,
    required this.title,
    required this.language,
    required this.subject,
    required this.grade,
    required this.questions,
  });

  factory QuestionPack.fromJson(Map<String, dynamic> json) {
    return QuestionPack(
      id: json['id'] as String? ?? '',
      title: _repairText(json['title'] as String? ?? ''),
      language: json['language'] as String? ?? '',
      subject: _repairText(json['subject'] as String? ?? ''),
      grade: _repairText(json['grade'] as String? ?? ''),
      questions: jsonInt(json['questions']),
    );
  }

  final String id;
  final String title;
  final String language;
  final String subject;
  final String grade;
  final int questions;

  String get label => '$title ($questions questions)';
}

String _repairText(String value) {
  if (value.codeUnits.any((codeUnit) => codeUnit > 0xFF)) {
    return value;
  }

  try {
    return utf8.decode(latin1.encode(value));
  } on FormatException {
    return value;
  }
}

class PacksResponse {
  const PacksResponse({
    required this.count,
    required this.packs,
    required this.openRooms,
  });

  factory PacksResponse.fromJson(Map<String, dynamic> json) {
    final packsJson = json['packs'] as List<dynamic>? ?? const [];

    return PacksResponse(
      count: jsonInt(json['count'], fallback: packsJson.length),
      packs: packsJson
          .map((pack) => QuestionPack.fromJson(pack as Map<String, dynamic>))
          .toList(),
      openRooms: jsonInt(json['open_rooms']),
    );
  }

  final int count;
  final List<QuestionPack> packs;
  final int openRooms;
}
