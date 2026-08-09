import 'package:sporcle/models/question_pack.dart';
import 'package:sporcle/models/json_helpers.dart';

enum GamePhase { connecting, lobby, question, reveal, finalPhase, error }

enum RoomMode {
  classic('classic'),
  wager('wager');

  const RoomMode(this.apiValue);

  factory RoomMode.fromJson(String? value) {
    return value == wager.apiValue ? wager : classic;
  }

  final String apiValue;

  String get label => this == classic ? 'Classic' : 'Wager';
}

class CreateRoomRequest {
  const CreateRoomRequest({
    required this.packId,
    required this.mode,
    required this.seconds,
    required this.questionCount,
    required this.speedScoring,
  });

  final String packId;
  final RoomMode mode;
  final int seconds;
  final int questionCount;
  final bool speedScoring;

  Map<String, Object> toJson() {
    return {
      'pack_id': packId,
      'mode': mode.apiValue,
      'seconds': seconds,
      'question_count': questionCount,
      'speed_scoring': speedScoring,
    };
  }
}

class CreatedRoom {
  const CreatedRoom({
    required this.code,
    required this.mode,
    required this.seconds,
    required this.questionCount,
    required this.speedScoring,
    required this.pack,
  });

  factory CreatedRoom.fromJson(Map<String, dynamic> json) {
    return CreatedRoom(
      code: json['code'] as String? ?? '',
      mode: RoomMode.fromJson(json['mode'] as String?),
      seconds: jsonInt(json['seconds'], fallback: 20),
      questionCount: jsonInt(json['question_count'], fallback: 10),
      speedScoring: json['speed_scoring'] as bool? ?? true,
      pack: QuestionPack.fromJson(
        json['pack'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  final String code;
  final RoomMode mode;
  final int seconds;
  final int questionCount;
  final bool speedScoring;
  final QuestionPack pack;
}

class RoomPlayer {
  const RoomPlayer({
    required this.playerId,
    required this.name,
    required this.isHost,
    required this.score,
    required this.streak,
    required this.connected,
    required this.answered,
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json) {
    return RoomPlayer(
      playerId: json['player_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isHost: json['is_host'] as bool? ?? false,
      score: jsonInt(json['score']),
      streak: jsonInt(json['streak']),
      connected: json['connected'] as bool? ?? false,
      answered: json['answered'] as bool? ?? false,
    );
  }

  final String playerId;
  final String name;
  final bool isHost;
  final int score;
  final int streak;
  final bool connected;
  final bool answered;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.playerId,
    required this.name,
    required this.score,
    required this.correct,
    required this.bestStreak,
    required this.connected,
    required this.tokensLeft,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: jsonInt(json['rank']),
      playerId: json['player_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      score: jsonInt(json['score']),
      correct: jsonInt(json['correct']),
      bestStreak: jsonInt(json['best_streak']),
      connected: json['connected'] as bool? ?? false,
      tokensLeft: (json['tokens_left'] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((number) => number.toInt())
          .toList(),
    );
  }

  final int rank;
  final String playerId;
  final String name;
  final int score;
  final int correct;
  final int bestStreak;
  final bool connected;
  final List<int> tokensLeft;
}

class RoomQuestion {
  const RoomQuestion({required this.text, required this.choices});

  factory RoomQuestion.fromJson(Map<String, dynamic> json) {
    return RoomQuestion(
      text: json['text'] as String? ?? '',
      choices: (json['choices'] as List<dynamic>? ?? const [])
          .map((choice) => choice.toString())
          .toList(),
    );
  }

  final String text;
  final List<String> choices;
}

class RevealResult {
  const RevealResult({
    required this.playerId,
    required this.name,
    required this.chose,
    required this.correct,
    required this.gain,
    required this.score,
    required this.streak,
    this.wager,
    this.forfeited,
    required this.tokensLeft,
  });

  factory RevealResult.fromJson(Map<String, dynamic> json) {
    return RevealResult(
      playerId: json['player_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      chose: jsonOptionalInt(json['chose']),
      correct: json['correct'] as bool? ?? false,
      gain: jsonInt(json['gain']),
      score: jsonInt(json['score']),
      streak: jsonInt(json['streak']),
      wager: jsonOptionalInt(json['wager']),
      forfeited: jsonOptionalInt(json['forfeited']),
      tokensLeft: (json['tokens_left'] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((number) => number.toInt())
          .toList(),
    );
  }

  final String playerId;
  final String name;
  final int? chose;
  final bool correct;
  final int gain;
  final int score;
  final int streak;
  final int? wager;
  final int? forfeited;
  final List<int> tokensLeft;
}

class GameRoomState {
  const GameRoomState({
    this.phase = GamePhase.connecting,
    this.code = '',
    this.playerId,
    this.playerName,
    this.isHost = false,
    this.mode = RoomMode.classic,
    this.index = -1,
    this.total = 0,
    this.seconds = 20,
    this.speedScoring = true,
    this.remaining = 0,
    this.pack,
    this.players = const [],
    this.question,
    this.tokensLeft = const [],
    this.selectedChoice,
    this.selectedWager,
    this.answeredCount = 0,
    this.answerTotal = 0,
    this.answerRejectedReason,
    this.correctChoice,
    this.explain,
    this.counts = const [],
    this.results = const [],
    this.leaderboard = const [],
    this.hasNext = false,
    this.maxScore,
    this.errorMessage,
  });

  final GamePhase phase;
  final String code;
  final String? playerId;
  final String? playerName;
  final bool isHost;
  final RoomMode mode;
  final int index;
  final int total;
  final int seconds;
  final bool speedScoring;
  final int remaining;
  final QuestionPack? pack;
  final List<RoomPlayer> players;
  final RoomQuestion? question;
  final List<int> tokensLeft;
  final int? selectedChoice;
  final int? selectedWager;
  final int answeredCount;
  final int answerTotal;
  final String? answerRejectedReason;
  final int? correctChoice;
  final String? explain;
  final List<int> counts;
  final List<RevealResult> results;
  final List<LeaderboardEntry> leaderboard;
  final bool hasNext;
  final int? maxScore;
  final String? errorMessage;

  GameRoomState copyWith({
    GamePhase? phase,
    String? code,
    String? playerId,
    String? playerName,
    bool? isHost,
    RoomMode? mode,
    int? index,
    int? total,
    int? seconds,
    bool? speedScoring,
    int? remaining,
    QuestionPack? pack,
    List<RoomPlayer>? players,
    RoomQuestion? question,
    List<int>? tokensLeft,
    int? selectedChoice,
    bool clearSelectedChoice = false,
    int? selectedWager,
    bool clearSelectedWager = false,
    int? answeredCount,
    int? answerTotal,
    String? answerRejectedReason,
    bool clearAnswerRejectedReason = false,
    int? correctChoice,
    bool clearCorrectChoice = false,
    String? explain,
    bool clearExplain = false,
    List<int>? counts,
    List<RevealResult>? results,
    List<LeaderboardEntry>? leaderboard,
    bool? hasNext,
    int? maxScore,
    bool clearMaxScore = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return GameRoomState(
      phase: phase ?? this.phase,
      code: code ?? this.code,
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      isHost: isHost ?? this.isHost,
      mode: mode ?? this.mode,
      index: index ?? this.index,
      total: total ?? this.total,
      seconds: seconds ?? this.seconds,
      speedScoring: speedScoring ?? this.speedScoring,
      remaining: remaining ?? this.remaining,
      pack: pack ?? this.pack,
      players: players ?? this.players,
      question: question ?? this.question,
      tokensLeft: tokensLeft ?? this.tokensLeft,
      selectedChoice: clearSelectedChoice
          ? null
          : selectedChoice ?? this.selectedChoice,
      selectedWager: clearSelectedWager
          ? null
          : selectedWager ?? this.selectedWager,
      answeredCount: answeredCount ?? this.answeredCount,
      answerTotal: answerTotal ?? this.answerTotal,
      answerRejectedReason: clearAnswerRejectedReason
          ? null
          : answerRejectedReason ?? this.answerRejectedReason,
      correctChoice: clearCorrectChoice
          ? null
          : correctChoice ?? this.correctChoice,
      explain: clearExplain ? null : explain ?? this.explain,
      counts: counts ?? this.counts,
      results: results ?? this.results,
      leaderboard: leaderboard ?? this.leaderboard,
      hasNext: hasNext ?? this.hasNext,
      maxScore: clearMaxScore ? null : maxScore ?? this.maxScore,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
