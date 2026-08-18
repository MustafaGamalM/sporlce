import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporcle/main.dart';
import 'package:sporcle/models/concept_map.dart';
import 'package:sporcle/models/flashcard_deck.dart';
import 'package:sporcle/models/game_room.dart';
import 'package:sporcle/models/live_assistant.dart';
import 'package:sporcle/models/question_pack.dart';
import 'package:sporcle/services/api_service.dart';
import 'package:sporcle/views/live_assistant_view.dart';

void main() {
  testWidgets('shows game cards', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Choose a Game'), findsOneWidget);
    expect(find.text('Flashcards'), findsOneWidget);
    expect(find.text('Concept Maps'), findsOneWidget);
    expect(find.text('Room Game'), findsOneWidget);
    expect(find.text('Live Assistant'), findsOneWidget);
    expect(find.textContaining('lesson into smart'), findsOneWidget);
  });

  testWidgets('flashcards card opens generator controls', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Flashcards'));
    await tester.pumpAndSettle();

    expect(find.text('Lesson source'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Cards'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Generate cards'), findsOneWidget);
  });

  testWidgets('concept maps card opens generator controls', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Concept Maps'));
    await tester.pumpAndSettle();

    expect(find.text('Input'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Max concepts'), findsOneWidget);
    expect(find.text('Format'), findsOneWidget);
    expect(find.text('Strict hierarchy'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Generate map'), findsOneWidget);
  });

  testWidgets('live assistant screen shows session controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LiveAssistantView(apiService: _FakeLiveAssistantApiService()),
      ),
    );
    await tester.pump();

    expect(find.text('No lesson selected'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Subject'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Start live call'),
      findsOneWidget,
    );
  });

  testWidgets('join form requires a five character code and a name', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Room Game'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join a game'));
    await tester.pump();

    expect(find.text('Room code'), findsOneWidget);
    expect(find.text('Your name'), findsOneWidget);

    var joinButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Join'),
    );
    expect(joinButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'abcde');
    await tester.enterText(find.byType(TextField).last, 'Sara');
    await tester.pump();

    joinButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Join'),
    );
    expect(joinButton.onPressed, isNotNull);
  });

  testWidgets('host form exposes room configuration controls', (tester) async {
    tester.view.physicalSize = const Size(1360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Room Game'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Host a game'));
    await tester.pumpAndSettle();

    expect(find.text('Host a game'), findsOneWidget);
    expect(find.text('Your name'), findsOneWidget);
    expect(find.text('Question pack'), findsOneWidget);
    expect(find.text('Classic'), findsOneWidget);
    expect(find.text('Wager'), findsOneWidget);
    expect(find.text('Seconds per question'), findsOneWidget);
    expect(find.text('Questions'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Create and join'),
      findsOneWidget,
    );
  });

  test('parses room creation response', () {
    final room = CreatedRoom.fromJson({
      'code': 'L9PJ5',
      'mode': 'wager',
      'seconds': 20,
      'question_count': 10,
      'speed_scoring': false,
      'pack': {
        'id': 'en_photosynthesis',
        'title': 'Photosynthesis',
        'language': 'en',
        'subject': 'Biology',
        'grade': 'Grade 10',
        'questions': 30,
      },
    });

    expect(room.code, 'L9PJ5');
    expect(room.mode, RoomMode.wager);
    expect(room.questionCount, 10);
    expect(room.pack, isA<QuestionPack>());
  });

  test('parses flashcards response', () {
    final deck = FlashcardDeck.fromJson({
      'language': 'en',
      'count': 2,
      'cards': [
        {
          'type': 'basic',
          'front': 'Where does photosynthesis occur?',
          'back': 'Chloroplasts',
          'hint': null,
        },
        {
          'type': 'cloze',
          'front': 'Plants produce glucose and ____.',
          'back': 'oxygen',
          'hint': 'Gas released by plants',
        },
      ],
    });

    expect(deck.language, 'en');
    expect(deck.count, 2);
    expect(deck.cards.first.isCloze, isFalse);
    expect(deck.cards.last.isCloze, isTrue);
    expect(deck.cards.last.hint, 'Gas released by plants');
  });

  test('parses concept map response', () {
    final conceptMap = ConceptMap.fromJson({
      'language': 'en',
      'concepts': [
        {'id': 'c1', 'label': 'Photosynthesis'},
        {'id': 'c2', 'label': 'Green plants'},
        {'id': 'c3', 'label': 'Food creation'},
        {'id': 'c4', 'label': 'Sunlight'},
        {'id': 'c5', 'label': 'Carbon dioxide'},
        {'id': 'c6', 'label': 'Water'},
      ],
      'relationships': [
        {'from': 'c1', 'to': 'c2', 'type': 'depends_on'},
        {'from': 'c1', 'to': 'c3', 'type': 'leads_to'},
        {'from': 'c3', 'to': 'c4', 'type': 'part_of'},
        {'from': 'c3', 'to': 'c5', 'type': 'part_of'},
        {'from': 'c3', 'to': 'c6', 'type': 'part_of'},
      ],
      'image': {
        'url':
            'https://yahiaraouf.pythonanywhere.com/static/generated/f44fd1da5b664002b68d08431f6198bc.svg',
        'format': 'svg',
      },
    });

    expect(conceptMap.language, 'en');
    expect(conceptMap.concepts, hasLength(6));
    expect(conceptMap.relationships, hasLength(5));
    expect(conceptMap.relationships.first.type, 'depends_on');
    expect(conceptMap.image.format, 'svg');
    expect(conceptMap.image.url, contains('/static/generated/'));
  });

  test('parses whole-number JSON values even when decoded as doubles', () {
    final room = CreatedRoom.fromJson({
      'code': 'L9PJ5',
      'mode': 'classic',
      'seconds': 20.0,
      'question_count': 10.0,
      'speed_scoring': true,
      'pack': {
        'id': 'ar_biology_sec3',
        'title': 'أحياء الثانوية العامة',
        'language': 'ar',
        'subject': 'أحياء',
        'grade': 'الصف الثالث الثانوي',
        'questions': 30.0,
      },
    });
    final player = RoomPlayer.fromJson({
      'player_id': 'p1',
      'name': 'Sara',
      'is_host': false,
      'score': 12.0,
      'streak': 3.0,
      'connected': true,
      'answered': false,
    });
    final result = RevealResult.fromJson({
      'player_id': 'p1',
      'name': 'Sara',
      'chose': 1.0,
      'correct': true,
      'gain': 5.0,
      'score': 12.0,
      'streak': 3.0,
      'wager': 2.0,
      'tokens_left': [1.0, 3.0],
    });

    expect(room.seconds, 20);
    expect(room.questionCount, 10);
    expect(room.pack.questions, 30);
    expect(player.score, 12);
    expect(player.streak, 3);
    expect(result.chose, 1);
    expect(result.gain, 5);
    expect(result.wager, 2);
    expect(result.tokensLeft, [1, 3]);
  });

  test('parses Arabic pack text that is already valid Unicode', () {
    final pack = QuestionPack.fromJson({
      'id': 'ar_biology_sec3',
      'title': 'أحياء الثانوية العامة',
      'language': 'ar',
      'subject': 'أحياء',
      'grade': 'الصف الثالث الثانوي',
      'questions': 30,
    });

    expect(pack.title, 'أحياء الثانوية العامة');
    expect(pack.subject, 'أحياء');
    expect(pack.grade, 'الصف الثالث الثانوي');
  });
  test('parses live assistant JSON audio chunks', () {
    final incoming = LiveAssistantIncoming.fromJson({
      'type': 'audio',
      'audio_base64': 'AQIDBA==',
    });

    expect(incoming.type, 'audio');
    expect(incoming.audio, [1, 2, 3, 4]);
  });
}

class _FakeLiveAssistantApiService extends ApiService {
  @override
  Future<LiveAssistantConfig> getLiveAssistantConfig() async {
    return const LiveAssistantConfig(
      model: 'gemini-live',
      inputSampleRate: 16000,
      outputSampleRate: 24000,
      maxUploadMb: 20,
      accepts: [
        'application/pdf',
        'image/jpeg',
        'image/png',
        'image/webp',
        'image/heic',
        'image/heif',
        'text/plain',
      ],
      languages: ['en', 'ar'],
      subjects: ['general', 'biology', 'chemistry'],
      sessionsOpen: 0,
      maxConcurrentSessions: 4,
      idleSeconds: 120,
      maxSessionSeconds: 1200,
    );
  }
}
