import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sporcle/models/game_room.dart';
import 'package:sporcle/models/question_pack.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  static const String _baseUrl = 'https://study-room.yahia-lab.org';
  static const String _packsUrl = '$_baseUrl/api/v1/game/packs';
  static const String _roomsUrl = '$_baseUrl/api/v1/game/rooms';
  static const String _wsUrl = 'wss://study-room.yahia-lab.org/api/v1/game/ws';

  final http.Client _client;

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

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
