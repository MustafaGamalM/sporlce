import 'package:flutter/material.dart';
import 'package:sporcle/app_colors.dart';
import 'package:sporcle/views/flashcards_view.dart';
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
          'Turn your lesson into smart question-and-answer cards to review and memorize faster.',
      icon: Icons.style_rounded,
    ),
    GameItem(
      title: 'Room Game',
      description:
          'Create or join a multiplayer quiz room and compete with friends in real time.',
      icon: Icons.groups_rounded,
    ),
    GameItem(
      title: 'Study Plan',
      description:
          'Build a personalized study schedule based on your subjects, exam date, and available time.',
      icon: Icons.calendar_month_rounded,
    ),
  ];
  void onBack() {
    Navigator.pop(context);
  }

  void openGame(GameItem game) {
    if (game.title == 'Flashcards') {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (context) => const FlashcardsView()),
      );
      return;
    }

    if (game.title != 'Room Game') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This game is not ready yet.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => const RoomEntryView()),
    );
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
                  color: Colors.black.withValues(alpha: 0.65),
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
            color: Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
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
                      color: AppColors.partyPurple.withValues(alpha: 0.15),
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
                  color: Colors.black.withValues(alpha: 0.70),
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
                      Icon(Icons.arrow_forward_rounded, size: 19),
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
