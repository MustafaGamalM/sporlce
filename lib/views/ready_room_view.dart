import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sporcle/app_colors.dart';
import 'package:sporcle/manager/game_room_controller.dart';
import 'package:sporcle/models/game_room.dart';

class ReadyRoomView extends StatefulWidget {
  const ReadyRoomView({
    super.key,
    required this.controller,
    this.roomCode,
    this.playerName,
    this.shouldConnect = false,
  });

  final GameRoomController controller;
  final String? roomCode;
  final String? playerName;
  final bool shouldConnect;

  @override
  State<ReadyRoomView> createState() => _ReadyRoomViewState();
}

class _ReadyRoomViewState extends State<ReadyRoomView> {
  int? _selectedWager;

  @override
  void initState() {
    super.initState();
    if (widget.shouldConnect) {
      widget.controller.connect(
        roomCode: widget.roomCode ?? '',
        playerName: widget.playerName ?? '',
      );
    }
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  void _leave() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        return Scaffold(
          backgroundColor: AppColors.deepPurple,
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  children: [
                    const _RoomHeader(),
                    const SizedBox(height: 24),
                    _RoomBar(state: state, onLeave: _leave),
                    const SizedBox(height: 20),
                    switch (state.phase) {
                      GamePhase.connecting => const _CenteredStatus(
                        message: 'Joining room...',
                      ),
                      GamePhase.lobby => _LobbyView(
                        state: state,
                        onStart: widget.controller.startGame,
                      ),
                      GamePhase.question => _QuestionView(
                        state: state,
                        selectedWager: _selectedWager,
                        onWagerChanged: (value) {
                          setState(() => _selectedWager = value);
                        },
                        onAnswer: (choice) {
                          widget.controller.submitAnswer(
                            choice,
                            wager: state.mode == RoomMode.wager
                                ? _selectedWager
                                : null,
                          );
                        },
                      ),
                      GamePhase.reveal => _RevealView(state: state),
                      GamePhase.finalPhase => _FinalView(state: state),
                      GamePhase.error => _ErrorView(
                        message: state.errorMessage ?? 'Room unavailable.',
                      ),
                    },
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoomHeader extends StatelessWidget {
  const _RoomHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Game Room',
          style: textTheme.headlineMedium?.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A live room where everyone answers the same question at once and competes on points. No AI, no API key, and it keeps working when the Gemini quota is gone.',
          style: textTheme.titleMedium?.copyWith(
            color: AppColors.mutedText,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _RoomBar extends StatelessWidget {
  const _RoomBar({required this.state, required this.onLeave});

  final GameRoomState state;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final packTitle = state.pack?.title ?? 'Room';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.midnight,
        border: Border.all(color: AppColors.softGray),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            'ROOM',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
          const SizedBox(width: 10),
          Text(
            state.code.isEmpty ? '-----' : state.code,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.partyPurple,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              '${state.players.length} player${state.players.length == 1 ? '' : 's'} · ${state.mode.label} · $packTitle',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
            ),
          ),
          OutlinedButton(onPressed: onLeave, child: const Text('Leave')),
        ],
      ),
    );
  }
}

class _LobbyView extends StatelessWidget {
  const _LobbyView({required this.state, required this.onStart});

  final GameRoomState state;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final packTitle = state.pack?.title ?? 'Selected pack';
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          decoration: BoxDecoration(
            color: AppColors.blueTint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'Share this code',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
              ),
              const SizedBox(height: 12),
              Text(
                state.code,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.partyPurple,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 10,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${state.total} questions · ${state.seconds}s each · $packTitle · ${state.mode.label}',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: state.players.map((player) {
            return Chip(
              label: Text(player.name),
              avatar: player.isHost
                  ? const Icon(Icons.workspace_premium, size: 16)
                  : CircleAvatar(child: Text(player.name.characters.first)),
              backgroundColor: AppColors.midnight,
              side: BorderSide(
                color: player.isHost
                    ? AppColors.partyPurple
                    : AppColors.softGray,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 26),
        if (state.isHost)
          SizedBox(
            width: 176,
            child: FilledButton(
              onPressed: state.players.isEmpty ? null : onStart,
              child: const Text('Start the game'),
            ),
          )
        else
          const _CenteredStatus(message: 'Waiting for the host to start.'),
      ],
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.state,
    required this.selectedWager,
    required this.onWagerChanged,
    required this.onAnswer,
  });

  final GameRoomState state;
  final int? selectedWager;
  final ValueChanged<int?> onWagerChanged;
  final ValueChanged<int> onAnswer;

  @override
  Widget build(BuildContext context) {
    final question = state.question;
    if (question == null) {
      return const _CenteredStatus(message: 'Loading question...');
    }

    final progress = state.total <= 0 ? 0.0 : (state.index + 1) / state.total;
    final hasAnswered = state.selectedChoice != null;
    final needsWager = state.mode == RoomMode.wager;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: AppColors.softGray,
                  color: AppColors.partyPurple,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Question ${state.index + 1} of ${state.total}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Text(
          '${state.remaining}s',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.partyPurple,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Directionality(
          textDirection: _textDirection(question.text),
          child: Text(
            question.text,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 24),
        if (needsWager) ...[
          _WagerPicker(
            tokens: state.tokensLeft,
            selectedWager: selectedWager,
            enabled: !hasAnswered,
            onChanged: onWagerChanged,
          ),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 760;
            final width = isCompact
                ? constraints.maxWidth
                : (constraints.maxWidth - 16) / 2;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: question.choices.indexed.map((entry) {
                final index = entry.$1;
                final text = entry.$2;
                final enabled =
                    !hasAnswered && (!needsWager || selectedWager != null);
                return SizedBox(
                  width: width,
                  child: _AnswerButton(
                    label: String.fromCharCode(65 + index),
                    text: text,
                    selected: state.selectedChoice == index,
                    enabled: enabled,
                    onTap: () => onAnswer(index),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 18),
        if (state.answerRejectedReason != null)
          _Notice(
            message: 'Answer rejected: ${state.answerRejectedReason}',
            isError: true,
          )
        else if (hasAnswered)
          const _Notice(message: 'Answer locked. Waiting for everyone.'),
        const SizedBox(height: 8),
        Text(
          '${state.answeredCount} of ${max(state.answerTotal, state.players.length)} answered',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
        ),
      ],
    );
  }
}

class _RevealView extends StatelessWidget {
  const _RevealView({required this.state});

  final GameRoomState state;

  @override
  Widget build(BuildContext context) {
    final question = state.question;
    final me = _myResult(state);
    final isCorrect = me?.correct ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Notice(
          message: isCorrect ? 'Correct' : 'Not this time',
          isError: !isCorrect,
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Answer: ${state.correctChoice == null ? '-' : String.fromCharCode(65 + state.correctChoice!)}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (state.explain != null) ...[
          const SizedBox(height: 12),
          Directionality(
            textDirection: _textDirection(state.explain!),
            child: Text(
              state.explain!,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (question != null)
          ...question.choices.indexed.map((entry) {
            final index = entry.$1;
            final text = entry.$2;
            final count = index < state.counts.length ? state.counts[index] : 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RevealChoiceRow(
                label: String.fromCharCode(65 + index),
                text: text,
                count: count,
                total: max(1, state.players.length),
                correct: state.correctChoice == index,
              ),
            );
          }),
        const SizedBox(height: 14),
        _LeaderboardStrip(state: state),
        const SizedBox(height: 20),
        Text(
          state.hasNext
              ? 'Next question shortly...'
              : 'Final results shortly...',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.mutedText,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _FinalView extends StatelessWidget {
  const _FinalView({required this.state});

  final GameRoomState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Final scores',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (state.maxScore != null) ...[
          const SizedBox(height: 6),
          Text(
            'Perfect score: ${state.maxScore}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
          ),
        ],
        const SizedBox(height: 18),
        ...state.leaderboard.map((entry) {
          final isMe = entry.playerId == state.playerId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ScoreTile(entry: entry, isMe: isMe),
          );
        }),
      ],
    );
  }
}

class _WagerPicker extends StatelessWidget {
  const _WagerPicker({
    required this.tokens,
    required this.selectedWager,
    required this.enabled,
    required this.onChanged,
  });

  final List<int> tokens;
  final int? selectedWager;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: tokens.map((token) {
        final selected = token == selectedWager;
        return ChoiceChip(
          label: Text('$token'),
          selected: selected,
          onSelected: enabled ? (_) => onChanged(token) : null,
          selectedColor: AppColors.partyPurple,
          labelStyle: TextStyle(
            color: selected ? AppColors.white : AppColors.ink,
            fontWeight: FontWeight.w900,
          ),
          backgroundColor: AppColors.midnight,
          side: const BorderSide(color: AppColors.softGray),
        );
      }).toList(),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.text,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.blueTint : AppColors.midnight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? AppColors.partyPurple : AppColors.softGray,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: Directionality(
                  textDirection: _textDirection(text),
                  child: Text(
                    text,
                    textAlign: _textDirection(text) == TextDirection.rtl
                        ? TextAlign.right
                        : TextAlign.left,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _LetterBadge(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevealChoiceRow extends StatelessWidget {
  const _RevealChoiceRow({
    required this.label,
    required this.text,
    required this.count,
    required this.total,
    required this.correct,
  });

  final String label;
  final String text;
  final int count;
  final int total;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final fraction = count / total;
    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(
            '$count',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.midnight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.softGray),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    color: correct ? AppColors.partyPurple : AppColors.softGray,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Directionality(
                      textDirection: _textDirection(text),
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.ink,
                          fontWeight: correct
                              ? FontWeight.w900
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _LetterBadge(label),
      ],
    );
  }
}

class _LeaderboardStrip extends StatelessWidget {
  const _LeaderboardStrip({required this.state});

  final GameRoomState state;

  @override
  Widget build(BuildContext context) {
    final items = state.leaderboard.isNotEmpty
        ? state.leaderboard
        : state.players
              .map(
                (player) => LeaderboardEntry(
                  rank: 0,
                  playerId: player.playerId,
                  name: player.name,
                  score: player.score,
                  correct: 0,
                  bestStreak: player.streak,
                  connected: player.connected,
                  tokensLeft: const [],
                ),
              )
              .toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.blueTint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: items.take(4).map((entry) {
          return Expanded(
            child: Text(
              '${entry.name}  ${entry.score}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.entry, required this.isMe});

  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe ? AppColors.blueTint : AppColors.midnight,
        border: Border.all(
          color: isMe ? AppColors.partyPurple : AppColors.softGray,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _LetterBadge(entry.rank <= 0 ? '-' : '${entry.rank}'),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMe ? '${entry.name} (you)' : entry.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            '${entry.score} pts',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.partyPurple,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LetterBadge extends StatelessWidget {
  const _LetterBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.blueTint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.partyPurple,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isError ? AppColors.dangerTint : AppColors.blueTint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: isError ? AppColors.danger : AppColors.partyPurple,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CenteredStatus extends StatelessWidget {
  const _CenteredStatus({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.mutedText),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _Notice(message: message, isError: true);
  }
}

RevealResult? _myResult(GameRoomState state) {
  for (final result in state.results) {
    if (result.playerId == state.playerId) {
      return result;
    }
  }
  return null;
}

TextDirection _textDirection(String value) {
  return RegExp(r'[\u0600-\u06ff]').hasMatch(value)
      ? TextDirection.rtl
      : TextDirection.ltr;
}
