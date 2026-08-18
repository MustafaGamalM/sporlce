import 'dart:convert';
import 'dart:typed_data';

class LiveAssistantConfig {
  const LiveAssistantConfig({
    required this.model,
    required this.inputSampleRate,
    required this.outputSampleRate,
    required this.maxUploadMb,
    required this.accepts,
    required this.languages,
    required this.subjects,
    required this.sessionsOpen,
    required this.maxConcurrentSessions,
    required this.idleSeconds,
    required this.maxSessionSeconds,
  });

  factory LiveAssistantConfig.fromJson(Map<String, dynamic> json) {
    return LiveAssistantConfig(
      model: _readString(json['model'], 'gemini-live'),
      inputSampleRate: _readInt(json['input_sample_rate'], 16000),
      outputSampleRate: _readInt(json['output_sample_rate'], 24000),
      maxUploadMb: _readInt(json['max_upload_mb'], 20),
      accepts: _readStringList(json['accepts']),
      languages: _readStringList(json['languages'], fallback: const ['en']),
      subjects: _readStringList(json['subjects'], fallback: const ['general']),
      sessionsOpen: _readInt(json['sessions_open'], 0),
      maxConcurrentSessions: _readInt(json['max_concurrent_sessions'], 4),
      idleSeconds: _readInt(json['idle_seconds'], 120),
      maxSessionSeconds: _readInt(json['max_session_seconds'], 1200),
    );
  }

  final String model;
  final int inputSampleRate;
  final int outputSampleRate;
  final int maxUploadMb;
  final List<String> accepts;
  final List<String> languages;
  final List<String> subjects;
  final int sessionsOpen;
  final int maxConcurrentSessions;
  final int idleSeconds;
  final int maxSessionSeconds;

  bool get isBusy => sessionsOpen >= maxConcurrentSessions;
}

class LiveAssistantUpload {
  const LiveAssistantUpload({
    required this.kind,
    required this.filename,
    this.documentId,
    this.uri,
    this.mimeType,
    this.name,
  });

  factory LiveAssistantUpload.fromJson(Map<String, dynamic> json) {
    return LiveAssistantUpload(
      kind: _readString(json['kind'], 'file'),
      filename: _readString(json['filename'], 'document'),
      documentId: _nullableString(json['document_id']),
      uri: _nullableString(json['uri']),
      mimeType: _nullableString(json['mime_type']),
      name: _nullableString(json['name']),
    );
  }

  final String kind;
  final String filename;
  final String? documentId;
  final String? uri;
  final String? mimeType;
  final String? name;

  String get label {
    if (kind == 'pdf' && documentId != null) {
      return '$filename uploaded as PDF';
    }
    if (kind == 'image' && uri != null) {
      return '$filename uploaded as image';
    }
    return '$filename uploaded';
  }
}

class LiveAssistantOpening {
  const LiveAssistantOpening({
    required this.language,
    required this.subject,
    this.documentId,
    this.fileUri,
    this.mimeType,
  });

  final String language;
  final String subject;
  final String? documentId;
  final String? fileUri;
  final String? mimeType;

  Map<String, Object?> toJson() {
    return {
      'language': language,
      'subject': subject,
      'document_id': documentId,
      'file_uri': fileUri,
      'mime_type': mimeType,
    };
  }
}

class LiveAssistantIncoming {
  const LiveAssistantIncoming({
    required this.type,
    this.message,
    this.reason,
    this.state,
    this.text,
    this.audio,
    this.inputSampleRate,
    this.outputSampleRate,
    this.language,
    this.subject,
    this.maxSessionSeconds,
  });

  factory LiveAssistantIncoming.fromJson(Map<String, dynamic> json) {
    return LiveAssistantIncoming(
      type: _readString(json['type'], 'unknown'),
      message: _nullableString(json['message']),
      reason: _nullableString(json['reason']),
      state: _nullableString(json['state']),
      text: _nullableString(json['text']),
      audio: _readAudio(json),
      inputSampleRate: _nullableInt(json['input_sample_rate']),
      outputSampleRate: _nullableInt(json['output_sample_rate']),
      language: _nullableString(json['language']),
      subject: _nullableString(json['subject']),
      maxSessionSeconds: _nullableInt(json['max_session_seconds']),
    );
  }

  factory LiveAssistantIncoming.audio(Uint8List bytes) {
    return LiveAssistantIncoming(type: 'audio', audio: bytes);
  }

  final String type;
  final String? message;
  final String? reason;
  final String? state;
  final String? text;
  final Uint8List? audio;
  final int? inputSampleRate;
  final int? outputSampleRate;
  final String? language;
  final String? subject;
  final int? maxSessionSeconds;
}

String _readString(Object? value, String fallback) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return fallback;
}

String? _nullableString(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

int _readInt(Object? value, int fallback) {
  return _nullableInt(value) ?? fallback;
}

int? _nullableInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

List<String> _readStringList(
  Object? value, {
  List<String> fallback = const [],
}) {
  if (value is List) {
    final items = value.whereType<String>().where((item) => item.isNotEmpty);
    return items.toList(growable: false);
  }
  return fallback;
}

Uint8List? _readAudio(Map<String, dynamic> json) {
  final bytes = json['audio'];
  if (bytes is List<int>) {
    return Uint8List.fromList(bytes);
  }
  if (bytes is List) {
    return Uint8List.fromList(bytes.whereType<int>().toList(growable: false));
  }

  final base64Audio =
      _nullableString(json['audio_base64']) ??
      _nullableString(json['data']) ??
      _nullableString(json['chunk']);
  if (base64Audio == null) {
    return null;
  }

  try {
    return base64Decode(base64Audio);
  } on FormatException {
    return null;
  }
}
