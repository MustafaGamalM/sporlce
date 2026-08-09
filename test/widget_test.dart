import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporcle/main.dart';
import 'package:sporcle/models/game_room.dart';
import 'package:sporcle/models/question_pack.dart';

void main() {
  testWidgets('shows the game room entry actions', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Game Room'), findsOneWidget);
    expect(find.text('Host a game'), findsOneWidget);
    expect(find.text('Join a game'), findsOneWidget);
    expect(find.textContaining('same question at once'), findsOneWidget);
  });

  testWidgets('join form requires a five character code and a name', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

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
}
