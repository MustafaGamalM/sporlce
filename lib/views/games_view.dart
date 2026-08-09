import 'package:flutter/material.dart';
import 'package:sporcle/app_colors.dart';
import 'package:sporcle/views/ready_room_view.dart';
import 'package:sporcle/views/room_entry_view.dart';

class GamesView extends StatefulWidget {
  const GamesView({super.key});

  @override
  State<GamesView> createState() => _GamesViewState();
}

class _GamesViewState extends State<GamesView> {
  final List<GameItem> games = [
    GameItem(
      title: 'Flashcards',
      description:
      'Create smart study cards and review lessons quickly.',
      icon: Icons.style_rounded,
    ),
    GameItem(
      title: 'Room Game',
      description:
      'Play live quizzes with friends and compete for the top score.',
      icon: Icons.sports_esports_rounded,
    ),
    GameItem(
      title: 'Study Plan',
      description:
      'Organize your subjects and get a study schedule before your exam.',
      icon: Icons.event_note_rounded,
    ),
  ];
  void onBack() {
    Navigator.pop(context);
  }

  void openGame(GameItem game) {
    if(game.title =="Room Game" ){
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RoomEntryView(),
        ),
      );
    }
    /// todo add another games

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a Game',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Pick a game and enter the room to start playing.',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.65),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 28),

              ...games.map(
                    (game) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _gameCard(game),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gameCard(GameItem game) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => openGame(game),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.black.withOpacity(0.10),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.partyPurple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      game.icon,
                      color: AppColors.partyPurple,
                      size: 30,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Text(
                    game.title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Text(
                game.description,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.70),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => openGame(game),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.partyPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Open Game',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 19,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameItem {
  final String title;
  final String description;
  final IconData icon;

  const GameItem({
    required this.title,
    required this.description,
    required this.icon,
  });
}