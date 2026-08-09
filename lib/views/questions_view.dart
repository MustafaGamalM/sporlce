import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sporcle/app_colors.dart';
import 'package:sporcle/views/users_score_view.dart';

class QuestionsView extends StatefulWidget {
  const QuestionsView({super.key, required this.gameName});

  final String gameName;

  @override
  State<QuestionsView> createState() => _QuestionsViewState();
}

class _QuestionsViewState extends State<QuestionsView> {
  static const int _questionSeconds = 15;

  late int _secondsLeft;
  Timer? _timer;
  int? _selectedAnswerIndex;

  final _question = const _Question(
    text: 'Which planet is known as the Red Planet?',
    answers: ['Venus', 'Mars', 'Jupiter', 'Saturn'],
  );

  @override
  void initState() {
    super.initState();
    _secondsLeft = _questionSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 1) {
        _goToScores();
        return;
      }

      setState(() {
        _secondsLeft--;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _selectAnswer(int index) {
    setState(() {
      _selectedAnswerIndex = index;
    });
  }

  void _goToScores() {
    _timer?.cancel();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => UsersScoreView(gameName: widget.gameName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      appBar: AppBar(title: const Text('Question'), centerTitle: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.gameName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  avatar: const Icon(
                    Icons.timer,
                    size: 18,
                    color: AppColors.partyPurple,
                  ),
                  label: Text('$_secondsLeft s'),
                  backgroundColor: AppColors.midnight,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              _question.text,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            ..._question.answers.indexed.map((answer) {
              final index = answer.$1;
              final text = answer.$2;
              final isSelected = _selectedAnswerIndex == index;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AnswerCard(
                  text: text,
                  isSelected: isSelected,
                  onTap: () => _selectAnswer(index),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Question {
  const _Question({required this.text, required this.answers});

  final String text;
  final List<String> answers;
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected ? AppColors.softGray : AppColors.midnight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? AppColors.partyPurple : AppColors.softGray,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.partyPurple : AppColors.pink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
