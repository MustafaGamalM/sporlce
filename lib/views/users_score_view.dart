import 'package:flutter/material.dart';
import 'package:sporcle/app_colors.dart';

class UsersScoreView extends StatelessWidget {
  const UsersScoreView({super.key, required this.gameName});

  final String gameName;

  static const List<_UserScore> _scores = [
    _UserScore(name: 'Mona', score: 90),
    _UserScore(name: 'You', score: 80),
    _UserScore(name: 'Salma', score: 70),
    _UserScore(name: 'Omar', score: 40),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      appBar: AppBar(title: const Text('Scores'), centerTitle: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              gameName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Users score',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ..._scores.indexed.map((score) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ScoreTile(
                  rank: score.$1 + 1,
                  name: score.$2.name,
                  score: score.$2.score,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _UserScore {
  const _UserScore({required this.name, required this.score});

  final String name;
  final int score;
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    required this.rank,
    required this.name,
    required this.score,
  });

  final int rank;
  final String name;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.midnight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.partyPurple),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rank == 1 ? AppColors.yellow : AppColors.pink,
          foregroundColor: AppColors.ink,
          child: Text('$rank'),
        ),
        title: Text(
          name == 'You' ? '$name (current)' : name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        trailing: Text(
          '$score pts',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.partyPurple,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
