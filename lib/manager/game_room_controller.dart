import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sporcle/models/game_room.dart';
import 'package:sporcle/models/json_helpers.dart';
import 'package:sporcle/models/question_pack.dart';
import 'package:sporcle/services/api_service.dart';

class GameRoomController extends ChangeNotifier {
  GameRoomController({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  GameRoomSocket? _socket;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _countdownTimer;
  int _localRemaining = 0;

  GameRoomState state = const GameRoomState();

  bool get isConnected => _socket != null;

  Future<CreatedRoom> createRoom(CreateRoomRequest request) {
    return _apiService.createRoom(request);
  }

  Future<void> connect({
    required String roomCode,
    required String playerName,
    QuestionPack? initialPack,
    RoomMode? initialMode,
    int? initialSeconds,
    int? initialTotal,
    bool? initialSpeedScoring,
  }) async {
    await leave(notify: false);
    state = state.copyWith(
      phase: GamePhase.connecting,
      code: roomCode.trim().toUpperCase(),
      playerName: playerName.trim().isEmpty ? 'Player' : playerName.trim(),
      pack: initialPack,
      mode: initialMode,
      seconds: initialSeconds,
      total: initialTotal,
      speedScoring: initialSpeedScoring,
      clearErrorMessage: true,
    );
    notifyListeners();

    try {
      _socket = _apiService.connectToRoom(
        roomCode: roomCode,
        playerName: playerName,
      );
      _subscription = _socket!.messages.listen(
        _handleMessage,
        onError: (Object error) => _setError(error.toString()),
        onDone: () {
          if (state.phase != GamePhase.finalPhase &&
              state.phase != GamePhase.error) {
            _setError('Connection closed. Rejoin creates a new player.');
          }
        },
      );
      _send({'type': 'state'});
    } catch (error) {
      _setError(error.toString());
    }
  }

  void startGame() {
    _send({'type': 'start'});
  }

  void submitAnswer(int choice, {int? wager}) {
    state = state.copyWith(
      selectedChoice: choice,
      selectedWager: wager,
      clearAnswerRejectedReason: true,
    );
    notifyListeners();

    final message = <String, Object?>{'type': 'answer', 'choice': choice};
    if (wager != null) {
      message['wager'] = wager;
    }
    _send(message);
  }

  Future<void> leave({bool notify = true}) async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _socket?.close();
    _socket = null;
    if (notify) {
      state = const GameRoomState();
      notifyListeners();
    }
  }

  void _handleMessage(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'ping':
        _send({'type': 'pong', 't': message['t']});
      case 'welcome':
        state = state.copyWith(
          playerId: message['player_id'] as String?,
          playerName: message['name'] as String?,
          isHost: message['is_host'] as bool?,
          code: message['code'] as String?,
          mode: RoomMode.fromJson(message['mode'] as String?),
          tokensLeft: _intList(message['tokens_left']),
          clearErrorMessage: true,
        );
        notifyListeners();
      case 'state':
        _applyState(message);
      case 'question':
        _applyQuestion(message);
      case 'answered':
        state = state.copyWith(
          answeredCount: jsonInt(message['answered']),
          answerTotal: jsonInt(message['total']),
        );
        notifyListeners();
      case 'answer_ack':
        state = state.copyWith(
          selectedChoice: jsonOptionalInt(message['choice']),
          selectedWager: jsonOptionalInt(message['wager']),
          tokensLeft: _intList(message['tokens_left']),
          clearAnswerRejectedReason: true,
        );
        notifyListeners();
      case 'answer_rejected':
        state = state.copyWith(
          answerRejectedReason: message['reason'] as String? ?? 'rejected',
          clearSelectedChoice: true,
          clearSelectedWager: true,
        );
        notifyListeners();
      case 'reveal':
        _applyReveal(message);
      case 'final':
        _applyFinal(message);
      case 'error':
        _setError(message['message'] as String? ?? 'Room error');
    }
  }

  void _applyState(Map<String, dynamic> message) {
    final phase = switch (message['phase'] as String?) {
      'question' => GamePhase.question,
      'reveal' => GamePhase.reveal,
      'final' => GamePhase.finalPhase,
      _ => GamePhase.lobby,
    };

    final packJson = message['pack'] as Map<String, dynamic>?;
    state = state.copyWith(
      phase: phase,
      code: message['code'] as String?,
      mode: RoomMode.fromJson(message['mode'] as String?),
      index: jsonInt(message['index'], fallback: -1),
      total: jsonInt(message['total']),
      seconds: jsonInt(message['seconds'], fallback: 20),
      speedScoring: message['speed_scoring'] as bool? ?? true,
      remaining: jsonInt(message['remaining'], fallback: state.remaining),
      pack: packJson == null ? null : QuestionPack.fromJson(packJson),
      players: (message['players'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RoomPlayer.fromJson)
          .toList(),
      clearErrorMessage: true,
    );
    if (phase != GamePhase.question) {
      _stopCountdown();
    }
    notifyListeners();
  }

  void _applyQuestion(Map<String, dynamic> message) {
    final seconds = jsonInt(message['seconds'], fallback: state.seconds);
    state = state.copyWith(
      phase: GamePhase.question,
      index: jsonInt(message['index'], fallback: state.index),
      total: jsonInt(message['total'], fallback: state.total),
      seconds: seconds,
      remaining: seconds,
      mode: RoomMode.fromJson(message['mode'] as String?),
      question: RoomQuestion.fromJson(
        message['question'] as Map<String, dynamic>? ?? const {},
      ),
      answeredCount: 0,
      answerTotal: state.players.length,
      counts: const [],
      results: const [],
      clearSelectedChoice: true,
      clearSelectedWager: true,
      clearCorrectChoice: true,
      clearExplain: true,
      clearAnswerRejectedReason: true,
      clearErrorMessage: true,
    );
    _startCountdown(seconds);
    notifyListeners();
  }

  void _applyReveal(Map<String, dynamic> message) {
    _stopCountdown();
    state = state.copyWith(
      phase: GamePhase.reveal,
      index: jsonInt(message['index'], fallback: state.index),
      mode: RoomMode.fromJson(message['mode'] as String?),
      correctChoice: jsonOptionalInt(message['correct']),
      explain: message['explain'] as String?,
      counts: _intList(message['counts']),
      results: (message['results'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RevealResult.fromJson)
          .toList(),
      leaderboard: _leaderboard(message),
      hasNext: message['has_next'] as bool? ?? false,
      clearAnswerRejectedReason: true,
    );
    RevealResult? me;
    for (final result in state.results) {
      if (result.playerId == state.playerId) {
        me = result;
        break;
      }
    }
    if (me != null) {
      state = state.copyWith(tokensLeft: me.tokensLeft);
    }
    notifyListeners();
  }

  void _applyFinal(Map<String, dynamic> message) {
    _stopCountdown();
    final packJson = message['pack'] as Map<String, dynamic>?;
    state = state.copyWith(
      phase: GamePhase.finalPhase,
      mode: RoomMode.fromJson(message['mode'] as String?),
      total: jsonInt(message['total_questions'], fallback: state.total),
      maxScore: jsonOptionalInt(message['max_score']),
      leaderboard: _leaderboard(message),
      pack: packJson == null ? state.pack : QuestionPack.fromJson(packJson),
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  List<LeaderboardEntry> _leaderboard(Map<String, dynamic> message) {
    return (message['leaderboard'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LeaderboardEntry.fromJson)
        .toList();
  }

  void _startCountdown(int seconds) {
    _stopCountdown();
    _localRemaining = seconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_localRemaining <= 0) {
        _stopCountdown();
        return;
      }
      _localRemaining--;
      state = state.copyWith(remaining: _localRemaining);
      notifyListeners();
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _send(Map<String, Object?> message) {
    _socket?.send(message);
  }

  void _setError(String message) {
    _stopCountdown();
    state = state.copyWith(phase: GamePhase.error, errorMessage: message);
    notifyListeners();
  }

  List<int> _intList(Object? value) {
    return (value as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((number) => number.toInt())
        .toList();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _subscription?.cancel();
    _socket?.close();
    super.dispose();
  }
}
