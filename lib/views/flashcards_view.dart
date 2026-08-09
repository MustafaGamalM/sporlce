import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sporcle/app_colors.dart';
import 'package:sporcle/models/flashcard_deck.dart';
import 'package:sporcle/services/api_service.dart';

class FlashcardsView extends StatefulWidget {
  const FlashcardsView({super.key, ApiService? apiService})
    : _apiService = apiService;

  final ApiService? _apiService;

  @override
  State<FlashcardsView> createState() => _FlashcardsViewState();
}

class _FlashcardsViewState extends State<FlashcardsView> {
  late final ApiService _apiService;
  final TextEditingController _lessonController = TextEditingController();
  final TextEditingController _numCardsController = TextEditingController(
    text: '10',
  );

  String _language = 'en';
  bool _isGenerating = false;
  FlashcardDeck? _deck;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiService = widget._apiService ?? ApiService();
  }

  @override
  void dispose() {
    _lessonController.dispose();
    _numCardsController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final text = _lessonController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Paste or type lesson text first.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final deck = await _apiService.generateFlashcards(
        GenerateFlashcardsRequest(
          text: text,
          language: _language,
          numCards: _readCardCount(),
        ),
      );

      if (mounted) {
        setState(() => _deck = deck);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  int _readCardCount() {
    final count = int.tryParse(_numCardsController.text.trim()) ?? 10;
    return count.clamp(1, 30);
  }

  @override
  Widget build(BuildContext context) {
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
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.partyPurple,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Flashcards',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Generate basic and cloze cards from lesson text.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.mutedText,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),
                _GeneratorCard(
                  lessonController: _lessonController,
                  numCardsController: _numCardsController,
                  language: _language,
                  isGenerating: _isGenerating,
                  error: _error,
                  onLanguageChanged: (value) {
                    if (value != null) {
                      setState(() => _language = value);
                    }
                  },
                  onGenerate: _isGenerating ? null : _generate,
                ),
                if (_deck != null) ...[
                  const SizedBox(height: 22),
                  _DeckView(deck: _deck!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GeneratorCard extends StatelessWidget {
  const _GeneratorCard({
    required this.lessonController,
    required this.numCardsController,
    required this.language,
    required this.isGenerating,
    required this.error,
    required this.onLanguageChanged,
    required this.onGenerate,
  });

  final TextEditingController lessonController;
  final TextEditingController numCardsController;
  final String language;
  final bool isGenerating;
  final String? error;
  final ValueChanged<String?> onLanguageChanged;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
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
              'Lesson source',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: lessonController,
              minLines: 7,
              maxLines: 12,
              textDirection: _textDirection(lessonController.text),
              decoration: _inputDecoration(
                'Paste the lesson text here...',
              ).copyWith(alignLabelWithHint: true),
              onChanged: (_) {},
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 20,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 180,
                  child: _LabeledField(
                    label: 'Language',
                    child: DropdownButtonFormField<String>(
                      initialValue: language,
                      decoration: _inputDecoration(null),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'ar', child: Text('Arabic')),
                      ],
                      onChanged: onLanguageChanged,
                    ),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: _LabeledField(
                    label: 'Cards',
                    child: TextField(
                      controller: numCardsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDecoration(null),
                    ),
                  ),
                ),
                SizedBox(
                  width: 176,
                  child: FilledButton.icon(
                    onPressed: onGenerate,
                    icon: isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(
                      isGenerating ? 'Generating...' : 'Generate cards',
                    ),
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  error!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeckView extends StatelessWidget {
  const _DeckView({required this.deck});

  final FlashcardDeck deck;

  @override
  Widget build(BuildContext context) {
    final isRtl = deck.language == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${deck.count} cards generated',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              _Pill(deck.language.toUpperCase()),
            ],
          ),
          if (deck.note != null && deck.note!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              deck.note!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedText,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...deck.cards.map(
            (card) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FlashcardTile(card: card),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlashcardTile extends StatefulWidget {
  const _FlashcardTile({required this.card});

  final Flashcard card;

  @override
  State<_FlashcardTile> createState() => _FlashcardTileState();
}

class _FlashcardTileState extends State<_FlashcardTile> {
  bool _isShowingAnswer = false;

  void _toggleSide() {
    setState(() => _isShowingAnswer = !_isShowingAnswer);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final card = widget.card;
    final displayedText = _isShowingAnswer ? card.back : card.front;
    final cardLabel = _isShowingAnswer
        ? 'Answer'
        : card.isCloze
        ? 'Cloze'
        : 'Basic';
    final helperText = _isShowingAnswer
        ? 'Tap to show question'
        : 'Tap to show answer';

    return Semantics(
      button: true,
      label: helperText,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleSide,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _isShowingAnswer
                  ? AppColors.partyPurple
                  : AppColors.midnight,
              border: Border.all(
                color: _isShowingAnswer
                    ? AppColors.partyPurple
                    : AppColors.softGray,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Column(
                key: ValueKey(_isShowingAnswer),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Pill(cardLabel, isInverted: _isShowingAnswer),
                  const SizedBox(height: 12),
                  Directionality(
                    textDirection: _textDirection(displayedText),
                    child: Text(
                      displayedText,
                      style:
                          (_isShowingAnswer
                                  ? textTheme.headlineSmall
                                  : textTheme.titleMedium)
                              ?.copyWith(
                                color: _isShowingAnswer
                                    ? AppColors.white
                                    : AppColors.ink,
                                fontWeight: FontWeight.w900,
                                height: 1.35,
                              ),
                    ),
                  ),
                  if (!_isShowingAnswer &&
                      card.hint != null &&
                      card.hint!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Hint: ${card.hint}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      helperText,
                      style: textTheme.bodySmall?.copyWith(
                        color: _isShowingAnswer
                            ? AppColors.blueTint
                            : AppColors.mutedText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

class _Pill extends StatelessWidget {
  const _Pill(this.label, {this.isInverted = false});

  final String label;
  final bool isInverted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isInverted ? AppColors.white.withAlpha(32) : AppColors.blueTint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isInverted ? AppColors.white : AppColors.partyPurple,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
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

TextDirection _textDirection(String value) {
  return RegExp(r'[\u0600-\u06ff]').hasMatch(value)
      ? TextDirection.rtl
      : TextDirection.ltr;
}
