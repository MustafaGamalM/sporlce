import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sporcle/app_colors.dart';
import 'package:sporcle/manager/game_room_controller.dart';
import 'package:sporcle/views/ready_room_view.dart';
import 'package:sporcle/views/start_view.dart';

class RoomEntryView extends StatefulWidget {
  const RoomEntryView({super.key});

  @override
  State<RoomEntryView> createState() => _RoomEntryViewState();
}

class _RoomEntryViewState extends State<RoomEntryView> {
  final TextEditingController _roomCodeController = TextEditingController();
  final TextEditingController _joinNameController = TextEditingController();

  bool _isJoining = false;

  @override
  void dispose() {
    _roomCodeController.dispose();
    _joinNameController.dispose();
    super.dispose();
  }

  void _createRoom() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => const StartView()));
  }

  void _showJoinRoom() {
    setState(() => _isJoining = true);
  }

  void _openReadyRoom() {
    final controller = GameRoomController();
    final roomCode = _roomCodeController.text;
    final playerName = _joinNameController.text;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ReadyRoomView(
          controller: controller,
          roomCode: roomCode,
          playerName: playerName,
          shouldConnect: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canJoin =
        _roomCodeController.text.trim().length == 5 &&
        _joinNameController.text.trim().isNotEmpty;

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
                if (_isJoining)
                  _JoinRoomCard(
                    roomCodeController: _roomCodeController,
                    nameController: _joinNameController,
                    canJoin: canJoin,
                    onChanged: () => setState(() {}),
                    onJoin: _openReadyRoom,
                    onBack: () => setState(() => _isJoining = false),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 760;
                      final width = isCompact
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 20) / 2;
                      return Wrap(
                        spacing: 20,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: width,
                            child: _ActionCard(
                              icon: Icons.add,
                              title: 'Host a game',
                              subtitle:
                                  'Pick a pack and a mode, get a room code',
                              onTap: _createRoom,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _ActionCard(
                              icon: Icons.arrow_forward,
                              title: 'Join a game',
                              subtitle: 'Enter a code someone shared with you',
                              onTap: _showJoinRoom,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.midnight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.softGray),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.blueTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.partyPurple, size: 22),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinRoomCard extends StatelessWidget {
  const _JoinRoomCard({
    required this.roomCodeController,
    required this.nameController,
    required this.canJoin,
    required this.onChanged,
    required this.onJoin,
    required this.onBack,
  });

  final TextEditingController roomCodeController;
  final TextEditingController nameController;
  final bool canJoin;
  final VoidCallback onChanged;
  final VoidCallback onJoin;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.partyPurple,
            padding: EdgeInsets.zero,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 1,
          color: AppColors.midnight,
          shadowColor: AppColors.ink.withAlpha(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.softGray),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join a game',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 20,
                  runSpacing: 14,
                  children: [
                    SizedBox(
                      width: 240,
                      child: _LabeledField(
                        label: 'Room code',
                        child: TextField(
                          controller: roomCodeController,
                          autofocus: true,
                          maxLength: 5,
                          textCapitalization: TextCapitalization.characters,
                          decoration: _inputDecoration(
                            'A B C D E',
                          ).copyWith(counterText: ''),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp('[a-zA-Z0-9]'),
                            ),
                            UpperCaseTextFormatter(),
                            LengthLimitingTextInputFormatter(5),
                          ],
                          onChanged: (_) => onChanged(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 225,
                      child: _LabeledField(
                        label: 'Your name',
                        child: TextField(
                          controller: nameController,
                          maxLength: 24,
                          decoration: _inputDecoration(
                            'e.g. Sara',
                          ).copyWith(counterText: ''),
                          onChanged: (_) => onChanged(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'To try it alone, host a game in this tab then open this page in a second tab or window and join with the code.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: 92,
                  child: FilledButton(
                    onPressed: canJoin ? onJoin : null,
                    child: const Text('Join'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.mutedText,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
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

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
