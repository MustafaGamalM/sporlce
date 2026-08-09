import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sporcle/app_colors.dart';
import 'package:sporcle/manager/game_room_controller.dart';
import 'package:sporcle/manager/packs_cubit/packs_cubit.dart';
import 'package:sporcle/models/game_room.dart';
import 'package:sporcle/models/question_pack.dart';
import 'package:sporcle/views/ready_room_view.dart';

class StartView extends StatefulWidget {
  const StartView({super.key, this.initialMode});

  final RoomMode? initialMode;

  @override
  State<StartView> createState() => _StartViewState();
}

class _StartViewState extends State<StartView> {
  late final PacksCubit _packsCubit;
  final TextEditingController _hostNameController = TextEditingController();
  final TextEditingController _secondsController = TextEditingController(
    text: '20',
  );
  final TextEditingController _questionsController = TextEditingController(
    text: '10',
  );

  static const List<QuestionPack> _fallbackPacks = [
    QuestionPack(
      id: 'ar_biology_sec3',
      title: 'أحياء الثانوية العامة',
      language: 'ar',
      subject: 'أحياء',
      grade: 'الصف الثالث الثانوي',
      questions: 30,
    ),
    QuestionPack(
      id: 'classic_quiz',
      title: 'Classic Quiz',
      language: 'en',
      subject: 'General',
      grade: 'All grades',
      questions: 20,
    ),
    QuestionPack(
      id: 'sports_logos',
      title: 'Sports Logos',
      language: 'en',
      subject: 'Sports',
      grade: 'All grades',
      questions: 15,
    ),
  ];

  QuestionPack? _selectedPack = _fallbackPacks.first;
  RoomMode _selectedMode = RoomMode.classic;
  bool _speedScoring = true;
  bool _isCreating = false;
  String? _createError;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode ?? RoomMode.classic;
    if (_selectedMode == RoomMode.wager) {
      _speedScoring = false;
    }
    _packsCubit = PacksCubit()..getPacks();
  }

  @override
  void dispose() {
    _packsCubit.close();
    _hostNameController.dispose();
    _secondsController.dispose();
    _questionsController.dispose();
    super.dispose();
  }

  Future<void> _createAndJoin() async {
    final selectedPack = _selectedPack;
    if (selectedPack == null) {
      return;
    }

    setState(() {
      _isCreating = true;
      _createError = null;
    });

    final controller = GameRoomController();
    try {
      final createdRoom = await controller.createRoom(
        CreateRoomRequest(
          packId: selectedPack.id,
          mode: _selectedMode,
          seconds: _readInt(_secondsController.text, fallback: 20),
          questionCount: _readInt(_questionsController.text, fallback: 10),
          speedScoring: _speedScoring,
        ),
      );
      await controller.connect(
        roomCode: createdRoom.code,
        playerName: _hostNameController.text,
        initialPack: createdRoom.pack,
        initialMode: createdRoom.mode,
        initialSeconds: createdRoom.seconds,
        initialTotal: createdRoom.questionCount,
        initialSpeedScoring: createdRoom.speedScoring,
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (context) => ReadyRoomView(controller: controller),
        ),
      );
    } catch (error) {
      controller.dispose();
      if (mounted) {
        setState(() => _createError = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  int _readInt(String value, {required int fallback}) {
    return int.tryParse(value.trim()) ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BlocProvider.value(
      value: _packsCubit,
      child: Scaffold(
        backgroundColor: AppColors.deepPurple,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.partyPurple,
                        padding: EdgeInsets.zero,
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BlocBuilder<PacksCubit, PacksState>(
                    builder: (context, state) {
                      final packs = state is PacksSuccess
                          ? state.packs
                          : _fallbackPacks;
                      final selectedPack = _resolveSelectedPack(packs);

                      return _HostGameCard(
                        hostNameController: _hostNameController,
                        secondsController: _secondsController,
                        questionsController: _questionsController,
                        questionPacks: packs,
                        selectedPack: selectedPack,
                        selectedMode: _selectedMode,
                        speedScoring: _speedScoring,
                        packsState: state,
                        onRetryPacks: _packsCubit.getPacks,
                        onPackChanged: (pack) {
                          if (pack == null) {
                            return;
                          }
                          setState(() => _selectedPack = pack);
                        },
                        onModeChanged: (mode) {
                          setState(() {
                            _selectedMode = mode;
                            if (mode == RoomMode.wager) {
                              _speedScoring = false;
                            }
                          });
                        },
                        onSpeedScoringChanged: (value) {
                          setState(() => _speedScoring = value ?? false);
                        },
                        onCreateAndJoin: selectedPack == null
                            ? null
                            : _createAndJoin,
                        isCreating: _isCreating,
                        createError: _createError,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  QuestionPack? _resolveSelectedPack(List<QuestionPack> packs) {
    if (packs.isEmpty) {
      _selectedPack = null;
      return null;
    }

    final selectedPack = _selectedPack;
    if (selectedPack != null) {
      for (final pack in packs) {
        if (pack.id == selectedPack.id) {
          _selectedPack = pack;
          return pack;
        }
      }
    }

    _selectedPack = packs.first;
    return _selectedPack;
  }
}

class _HostGameCard extends StatelessWidget {
  const _HostGameCard({
    required this.hostNameController,
    required this.secondsController,
    required this.questionsController,
    required this.questionPacks,
    required this.selectedPack,
    required this.selectedMode,
    required this.speedScoring,
    required this.packsState,
    required this.onRetryPacks,
    required this.onPackChanged,
    required this.onModeChanged,
    required this.onSpeedScoringChanged,
    required this.onCreateAndJoin,
    required this.isCreating,
    required this.createError,
  });

  final TextEditingController hostNameController;
  final TextEditingController secondsController;
  final TextEditingController questionsController;
  final List<QuestionPack> questionPacks;
  final QuestionPack? selectedPack;
  final RoomMode selectedMode;
  final bool speedScoring;
  final PacksState packsState;
  final VoidCallback onRetryPacks;
  final ValueChanged<QuestionPack?> onPackChanged;
  final ValueChanged<RoomMode> onModeChanged;
  final ValueChanged<bool?> onSpeedScoringChanged;
  final VoidCallback? onCreateAndJoin;
  final bool isCreating;
  final String? createError;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 1,
      color: AppColors.midnight,
      shadowColor: AppColors.ink.withAlpha(30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.softGray),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Host a game',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 720;
                final fields = [
                  SizedBox(
                    width: isCompact ? double.infinity : 225,
                    child: _LabeledField(
                      label: 'Your name',
                      child: TextField(
                        controller: hostNameController,
                        decoration: _inputDecoration('e.g. Yahia'),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: isCompact ? double.infinity : 432,
                    child: _LabeledField(
                      label: 'Question pack',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<QuestionPack>(
                            key: ValueKey<String?>(selectedPack?.id),
                            initialValue: selectedPack,
                            isExpanded: true,
                            decoration: _inputDecoration(null),
                            items: questionPacks
                                .map(
                                  (pack) => DropdownMenuItem<QuestionPack>(
                                    value: pack,
                                    child: Text(pack.label),
                                  ),
                                )
                                .toList(),
                            onChanged: questionPacks.isEmpty
                                ? null
                                : onPackChanged,
                          ),
                          _PacksStatus(
                            state: packsState,
                            onRetry: onRetryPacks,
                          ),
                        ],
                      ),
                    ),
                  ),
                ];

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      fields.first,
                      const SizedBox(height: 16),
                      fields.last,
                    ],
                  );
                }

                return Wrap(
                  spacing: 20,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: fields,
                );
              },
            ),
            const SizedBox(height: 22),
            _FieldLabel('Game mode'),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 760;
                final cardWidth = isCompact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 16) / 2;

                return Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _ModeOptionCard(
                        title: 'Classic',
                        description:
                            'Answer fast. A correct answer is worth more the quicker it comes, and the slowest correct answer still earns half.',
                        isSelected: selectedMode == RoomMode.classic,
                        onTap: () => onModeChanged(RoomMode.classic),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _ModeOptionCard(
                        title: 'Wager',
                        description:
                            'Speed does not matter. You hold one token of each value from 1 up, and spend one per question. Correct pays that many points. Each value can be used only once.',
                        isSelected: selectedMode == RoomMode.wager,
                        onTap: () => onModeChanged(RoomMode.wager),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 20,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 158,
                  child: _LabeledField(
                    label: 'Seconds per question',
                    child: TextField(
                      controller: secondsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDecoration(null),
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: _LabeledField(
                    label: 'Questions',
                    child: TextField(
                      controller: questionsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDecoration(null),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (selectedMode == RoomMode.classic) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: speedScoring,
                      onChanged: onSpeedScoringChanged,
                      activeColor: AppColors.partyPurple,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Speed scoring (faster correct answers score more)',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Turn speed scoring off for revision: every correct answer is worth the same, so nobody is punished for thinking.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedText,
                  height: 1.3,
                ),
              ),
            ] else
              Text(
                'Wager mode ignores speed. Each player spends one token per question, and the token value is the possible point gain.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedText,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 16),
            if (createError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  createError!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: 182,
              child: FilledButton(
                onPressed: isCreating ? null : onCreateAndJoin,
                child: Text(isCreating ? 'Creating...' : 'Create and join'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PacksStatus extends StatelessWidget {
  const _PacksStatus({required this.state, required this.onRetry});

  final PacksState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (state is PacksLoading || state is PacksInitial) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading packs...',
              style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
            ),
          ],
        ),
      );
    }

    if (state is PacksFailure) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Using fallback packs.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedText,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.partyPurple,
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final success = state as PacksSuccess;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '${success.count} packs available | ${success.openRooms} open rooms',
        style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
      ),
    );
  }
}

class _ModeOptionCard extends StatelessWidget {
  const _ModeOptionCard({
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? AppColors.partyPurple : AppColors.softGray;

    return Material(
      color: isSelected ? AppColors.softGray : AppColors.midnight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: isSelected ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.partyPurple : AppColors.mutedText,
                size: 20,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedText,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_FieldLabel(label), const SizedBox(height: 8), child],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.mutedText,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

InputDecoration _inputDecoration(String? hintText) {
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: AppColors.midnight,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: AppColors.softGray),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: AppColors.partyPurple, width: 2),
    ),
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  );
}
