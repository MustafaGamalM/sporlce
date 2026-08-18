import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:sporcle/models/concept_map.dart';
import 'package:sporcle/models/flashcard_deck.dart';
import 'package:sporcle/models/game_room.dart';
import 'package:sporcle/models/live_assistant.dart';
import 'package:sporcle/models/question_pack.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  static const String _baseUrl = 'https://study-room.yahia-lab.org';
  static const String _flashcardsUrl =
      'https://yahiaraouf.pythonanywhere.com/api/v1/flashcards/generate';
  static const String _conceptMapUrl =
      'https://yahiaraouf.pythonanywhere.com/api/v1/concept-map/generate';
  static const String _liveAssistantBaseUrl = 'https://live.yahia-lab.org';
  static const String _liveConfigUrl =
      '$_liveAssistantBaseUrl/api/v1/live-assistant/config';
  static const String _liveUploadUrl =
      '$_liveAssistantBaseUrl/api/v1/live-assistant/upload';
  static const String _liveWsUrl =
      'wss://live.yahia-lab.org/api/v1/live-assistant/stream';
  static const String _packsUrl = '$_baseUrl/api/v1/game/packs';
  static const String _roomsUrl = '$_baseUrl/api/v1/game/rooms';
  static const String _wsUrl = 'wss://study-room.yahia-lab.org/api/v1/game/ws';

  final http.Client _client;

  Future<FlashcardDeck> generateFlashcards(
    GenerateFlashcardsRequest request,
  ) async {
    final response = await _client.post(
      Uri.parse(_flashcardsUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    final json = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readErrorDetail(json, response.statusCode));
    }

    if (json is! Map<String, dynamic>) {
      throw const ApiException('Invalid flashcards response');
    }

    return FlashcardDeck.fromJson(json);
  }

  Future<ConceptMap> generateConceptMap(
    GenerateConceptMapRequest request,
  ) async {
    final response = await _client.post(
      Uri.parse(_conceptMapUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    final json = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readErrorDetail(json, response.statusCode));
    }

    if (json is! Map<String, dynamic>) {
      throw const ApiException('Invalid concept map response');
    }

    return ConceptMap.fromJson(json);
  }

  Future<LiveAssistantConfig> getLiveAssistantConfig() async {
    final response = await _client.get(Uri.parse(_liveConfigUrl));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to load live assistant settings (${response.statusCode})',
      );
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map<String, dynamic>) {
      throw const ApiException('Invalid live assistant config response');
    }

    return LiveAssistantConfig.fromJson(json);
  }

  Future<LiveAssistantUpload> uploadLiveAssistantDocument({
    required String filename,
    String? path,
    Uint8List? bytes,
  }) async {
    if ((path == null || path.isEmpty) && (bytes == null || bytes.isEmpty)) {
      throw const ApiException('Choose a document before uploading.');
    }

    final request = http.MultipartRequest('POST', Uri.parse(_liveUploadUrl));
    if (bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
    } else {
      request.files.add(await http.MultipartFile.fromPath('file', path!));
    }

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    final json = _tryDecodeJson(response.bodyBytes);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_liveUploadError(response.statusCode, json));
    }

    if (json is! Map<String, dynamic>) {
      throw const ApiException('Invalid upload response');
    }

    return LiveAssistantUpload.fromJson(json);
  }

  Future<PacksResponse> getPacks() async {
    final response = await _client.get(Uri.parse(_packsUrl));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Failed to load packs (${response.statusCode})');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map<String, dynamic>) {
      throw const ApiException('Invalid packs response');
    }

    return PacksResponse.fromJson(json);
  }

  Future<CreatedRoom> createRoom(CreateRoomRequest request) async {
    final response = await _client.post(
      Uri.parse(_roomsUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Failed to create room (${response.statusCode})');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map<String, dynamic>) {
      throw const ApiException('Invalid room response');
    }

    return CreatedRoom.fromJson(json);
  }

  GameRoomSocket connectToRoom({
    required String roomCode,
    required String playerName,
  }) {
    final uri = Uri.parse(_wsUrl).replace(
      queryParameters: {
        'room': roomCode.trim().toUpperCase(),
        'name': playerName.trim().isEmpty ? 'Player' : playerName.trim(),
      },
    );

    return GameRoomSocket(WebSocketChannel.connect(uri));
  }

  LiveAssistantSocket connectToLiveAssistant() {
    return LiveAssistantSocket(WebSocketChannel.connect(Uri.parse(_liveWsUrl)));
  }
}

String _readErrorDetail(Object? json, int statusCode) {
  if (json is Map<String, dynamic>) {
    final detail = json['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    if (detail != null) {
      return detail.toString();
    }
  }
  return 'Request failed ($statusCode)';
}

class GameRoomSocket {
  GameRoomSocket(this._channel);

  final WebSocketChannel _channel;

  Stream<Map<String, dynamic>> get messages {
    return _channel.stream.map((event) {
      final decoded = jsonDecode(event.toString());
      if (decoded is! Map<String, dynamic>) {
        return <String, dynamic>{'type': 'unknown'};
      }
      return decoded;
    });
  }

  void send(Map<String, Object?> message) {
    _channel.sink.add(jsonEncode(message));
  }

  Future<void> close() async {
    await _channel.sink.close();
  }
}

class LiveAssistantSocket {
  LiveAssistantSocket(this._channel);

  final WebSocketChannel _channel;

  Stream<LiveAssistantIncoming> get messages {
    return _channel.stream.map((event) {
      if (event is Uint8List) {
        return LiveAssistantIncoming.audio(event);
      }
      if (event is List<int>) {
        return LiveAssistantIncoming.audio(Uint8List.fromList(event));
      }

      final decoded = _tryDecodeJson(utf8.encode(event.toString()));
      if (decoded is! Map<String, dynamic>) {
        return const LiveAssistantIncoming(
          type: 'unknown',
          message: 'The server sent a message the app could not read.',
        );
      }
      return LiveAssistantIncoming.fromJson(decoded);
    });
  }

  void sendOpening(LiveAssistantOpening opening) {
    _channel.sink.add(jsonEncode(opening.toJson()));
  }

  void sendText(String text) {
    _channel.sink.add(jsonEncode({'type': 'client_text', 'text': text}));
  }

  void sendAudio(Uint8List bytes) {
    _channel.sink.add(bytes);
  }

  Future<void> close() async {
    await _channel.sink.close();
  }
}

Object? _tryDecodeJson(List<int> bodyBytes) {
  if (bodyBytes.isEmpty) {
    return null;
  }
  try {
    return jsonDecode(utf8.decode(bodyBytes));
  } on FormatException {
    return null;
  }
}

String _liveUploadError(int statusCode, Object? json) {
  final detail = _readErrorDetail(json, statusCode);
  return switch (statusCode) {
    400 =>
      detail == 'Request failed (400)' ? 'The selected file is empty.' : detail,
    413 => 'The selected file is larger than the upload limit.',
    415 => 'This file type is not supported.',
    502 => 'The server could not read this PDF.',
    _ => detail,
  };
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
