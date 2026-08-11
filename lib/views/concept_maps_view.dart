import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sporcle/app_colors.dart';
import 'package:sporcle/models/concept_map.dart';
import 'package:sporcle/services/api_service.dart';

class ConceptMapsView extends StatefulWidget {
  const ConceptMapsView({super.key, ApiService? apiService})
    : _apiService = apiService;

  final ApiService? _apiService;

  @override
  State<ConceptMapsView> createState() => _ConceptMapsViewState();
}

class _ConceptMapsViewState extends State<ConceptMapsView> {
  late final ApiService _apiService;
  final TextEditingController _lessonController = TextEditingController(
    text:
        'Photosynthesis is the process green plants use to make food using sunlight, carbon dioxide, and water',
  );
  final TextEditingController _maxConceptsController = TextEditingController(
    text: '12',
  );

  String _language = 'en';
  String _format = 'svg';
  bool _hierarchical = true;
  bool _isGenerating = false;
  ConceptMap? _conceptMap;
  String? _error;
  Duration? _lastDuration;

  @override
  void initState() {
    super.initState();
    _apiService = widget._apiService ?? ApiService();
  }

  @override
  void dispose() {
    _lessonController.dispose();
    _maxConceptsController.dispose();
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

    final stopwatch = Stopwatch()..start();
    try {
      final conceptMap = await _apiService.generateConceptMap(
        GenerateConceptMapRequest(
          text: text,
          language: _language,
          maxConcepts: _readMaxConcepts(),
          format: _format,
          hierarchical: _hierarchical,
        ),
      );

      stopwatch.stop();
      if (mounted) {
        setState(() {
          _conceptMap = conceptMap;
          _lastDuration = stopwatch.elapsed;
        });
      }
    } catch (error) {
      stopwatch.stop();
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  int _readMaxConcepts() {
    final count = int.tryParse(_maxConceptsController.text.trim()) ?? 12;
    return count.clamp(2, 40);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
                  'Concept Maps',
                  style: textTheme.headlineMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Generate a hierarchical concept-map image from a lesson.',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.mutedText,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),
                _GeneratorCard(
                  lessonController: _lessonController,
                  maxConceptsController: _maxConceptsController,
                  language: _language,
                  format: _format,
                  hierarchical: _hierarchical,
                  isGenerating: _isGenerating,
                  error: _error,
                  onLanguageChanged: (value) {
                    if (value != null) {
                      setState(() => _language = value);
                    }
                  },
                  onFormatChanged: (value) {
                    if (value != null) {
                      setState(() => _format = value);
                    }
                  },
                  onHierarchyChanged: (value) {
                    setState(() => _hierarchical = value ?? false);
                  },
                  onGenerate: _isGenerating ? null : _generate,
                ),
                if (_isGenerating || _conceptMap != null) ...[
                  const SizedBox(height: 22),
                  _GenerationStatus(
                    conceptMap: _conceptMap,
                    isGenerating: _isGenerating,
                    duration: _lastDuration,
                    requestedFormat: _format,
                  ),
                ],
                if (_conceptMap != null) ...[
                  const SizedBox(height: 16),
                  _ConceptMapPreview(conceptMap: _conceptMap!),
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
    required this.maxConceptsController,
    required this.language,
    required this.format,
    required this.hierarchical,
    required this.isGenerating,
    required this.error,
    required this.onLanguageChanged,
    required this.onFormatChanged,
    required this.onHierarchyChanged,
    required this.onGenerate,
  });

  final TextEditingController lessonController;
  final TextEditingController maxConceptsController;
  final String language;
  final String format;
  final bool hierarchical;
  final bool isGenerating;
  final String? error;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<String?> onFormatChanged;
  final ValueChanged<bool?> onHierarchyChanged;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
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
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 760;
                return Wrap(
                  spacing: 20,
                  runSpacing: 14,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(
                      width: isCompact ? double.infinity : 160,
                      child: _LabeledField(
                        label: 'Input',
                        child: DropdownButtonFormField<String>(
                          initialValue: 'paste',
                          decoration: _inputDecoration(null),
                          items: const [
                            DropdownMenuItem(
                              value: 'paste',
                              child: Text('Paste text'),
                            ),
                          ],
                          onChanged: null,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: isCompact ? double.infinity : 150,
                      child: _LabeledField(
                        label: 'Language',
                        child: DropdownButtonFormField<String>(
                          initialValue: language,
                          decoration: _inputDecoration(null),
                          items: const [
                            DropdownMenuItem(
                              value: 'en',
                              child: Text('English'),
                            ),
                            DropdownMenuItem(
                              value: 'ar',
                              child: Text('Arabic'),
                            ),
                          ],
                          onChanged: onLanguageChanged,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: isCompact ? double.infinity : 130,
                      child: _LabeledField(
                        label: 'Max concepts',
                        child: TextField(
                          controller: maxConceptsController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _inputDecoration(null),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: isCompact ? double.infinity : 120,
                      child: _LabeledField(
                        label: 'Format',
                        child: DropdownButtonFormField<String>(
                          initialValue: format,
                          decoration: _inputDecoration(null),
                          items: const [
                            DropdownMenuItem(value: 'svg', child: Text('SVG')),
                          ],
                          onChanged: onFormatChanged,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 46,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: hierarchical,
                            onChanged: onHierarchyChanged,
                            activeColor: AppColors.partyPurple,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Strict hierarchy',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.mutedText,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            TextField(
              controller: lessonController,
              minLines: 5,
              maxLines: 9,
              textDirection: _textDirection(lessonController.text),
              decoration: _inputDecoration(
                'Paste the lesson text here...',
              ).copyWith(alignLabelWithHint: true),
              onChanged: (_) {},
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 178,
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
                    : const Icon(Icons.account_tree_rounded, size: 18),
                label: Text(isGenerating ? 'Generating...' : 'Generate map'),
              ),
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

class _GenerationStatus extends StatelessWidget {
  const _GenerationStatus({
    required this.conceptMap,
    required this.isGenerating,
    required this.duration,
    required this.requestedFormat,
  });

  final ConceptMap? conceptMap;
  final bool isGenerating;
  final Duration? duration;
  final String requestedFormat;

  @override
  Widget build(BuildContext context) {
    final conceptCount = conceptMap?.concepts.length ?? 0;
    final linkCount = conceptMap?.relationships.length ?? 0;
    final seconds = duration == null
        ? null
        : (duration!.inMilliseconds / 1000).toStringAsFixed(1);

    return Card(
      elevation: 1,
      color: AppColors.midnight,
      shadowColor: AppColors.ink.withAlpha(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.softGray),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: isGenerating ? null : 1,
                backgroundColor: AppColors.softGray,
                color: const Color(0xFF20C77A),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isGenerating
                        ? 'Generating concept map...'
                        : '$conceptCount concepts, $linkCount links',
                    style: const TextStyle(
                      color: Color(0xFF148653),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (seconds != null)
                  Text(
                    '${seconds}s',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _StatusLine(
              label: 'Sending the lesson to Gemini',
              trailing: isGenerating ? null : '',
            ),
            _StatusLine(
              label: 'Gemini builds the concept graph',
              trailing: conceptMap == null ? null : '$conceptCount concepts',
            ),
            _StatusLine(
              label: 'Enforcing the hierarchy',
              trailing: conceptMap == null ? null : '$linkCount links',
            ),
            _StatusLine(
              label: 'Rendering the image',
              trailing:
                  conceptMap?.image.format.toUpperCase() ??
                  requestedFormat.toUpperCase(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 9, color: Color(0xFF20C77A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null && trailing!.isNotEmpty)
            Text(
              trailing!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _ConceptMapPreview extends StatefulWidget {
  const _ConceptMapPreview({required this.conceptMap});

  final ConceptMap conceptMap;

  @override
  State<_ConceptMapPreview> createState() => _ConceptMapPreviewState();
}

class _ConceptMapPreviewState extends State<_ConceptMapPreview> {
  final TransformationController _controller = TransformationController();
  double _scale = 1;
  Size? _viewportSize;
  Size? _layoutSize;
  String? _layoutKey;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _zoom(double delta) {
    final nextScale = (_scale + delta).clamp(0.6, 3.2).toDouble();
    final viewportSize = _viewportSize;
    final layoutSize = _layoutSize;
    setState(() {
      _scale = nextScale;
      _controller.value = _centeredMatrix(
        scale: nextScale,
        viewportSize: viewportSize,
        layoutSize: layoutSize,
      );
    });
  }

  void _resetZoom() {
    final viewportSize = _viewportSize;
    final layoutSize = _layoutSize;
    if (viewportSize == null || layoutSize == null) {
      return;
    }
    final fitScale = _fitScale(viewportSize, layoutSize);
    setState(() {
      _scale = fitScale;
      _controller.value = _centeredMatrix(
        scale: fitScale,
        viewportSize: viewportSize,
        layoutSize: layoutSize,
      );
    });
  }

  void _fitToScreen({
    required _ConceptMapLayout layout,
    required BoxConstraints constraints,
  }) {
    final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
    final layoutSize = Size(layout.width, layout.height);
    final nextLayoutKey =
        '${widget.conceptMap.concepts.length}-${widget.conceptMap.relationships.length}-${layout.width}-${layout.height}';

    _viewportSize = viewportSize;
    _layoutSize = layoutSize;

    if (_layoutKey == nextLayoutKey) {
      return;
    }
    _layoutKey = nextLayoutKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final fitScale = _fitScale(viewportSize, layoutSize);
      setState(() {
        _scale = fitScale;
        _controller.value = _centeredMatrix(
          scale: fitScale,
          viewportSize: viewportSize,
          layoutSize: layoutSize,
        );
      });
    });
  }

  double _fitScale(Size viewportSize, Size layoutSize) {
    final widthScale = viewportSize.width / layoutSize.width;
    final heightScale = viewportSize.height / layoutSize.height;
    final scale = widthScale < heightScale ? widthScale : heightScale;
    return scale.clamp(0.25, 1).toDouble();
  }

  Matrix4 _centeredMatrix({
    required double scale,
    required Size? viewportSize,
    required Size? layoutSize,
  }) {
    final matrix = Matrix4.diagonal3Values(scale, scale, 1);
    if (viewportSize == null || layoutSize == null) {
      return matrix;
    }

    final dx = (viewportSize.width - layoutSize.width * scale) / 2;
    final dy = (viewportSize.height - layoutSize.height * scale) / 2;
    matrix.setTranslationRaw(dx < 0 ? 0 : dx, dy < 0 ? 0 : dy, 0);
    return matrix;
  }

  @override
  Widget build(BuildContext context) {
    final layout = _ConceptMapLayout.from(widget.conceptMap);

    return Card(
      elevation: 1,
      color: AppColors.midnight,
      shadowColor: AppColors.ink.withAlpha(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.softGray),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ZoomButton(
                  icon: Icons.remove,
                  label: 'Zoom out',
                  onPressed: () => _zoom(-0.2),
                ),
                _ZoomButton(
                  icon: Icons.add,
                  label: 'Zoom in',
                  onPressed: () => _zoom(0.2),
                ),
                _ZoomButton(
                  icon: Icons.center_focus_strong,
                  label: 'Reset zoom',
                  onPressed: _resetZoom,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                height: 460,
                color: const Color(0xFFFBFDFF),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _fitToScreen(layout: layout, constraints: constraints);

                    return InteractiveViewer(
                      transformationController: _controller,
                      constrained: false,
                      minScale: 0.25,
                      maxScale: 3.2,
                      boundaryMargin: const EdgeInsets.all(180),
                      onInteractionUpdate: (_) {
                        setState(() {
                          _scale = _controller.value.getMaxScaleOnAxis();
                        });
                      },
                      child: SizedBox(
                        width: layout.width,
                        height: layout.height,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _ConceptMapPainter(layout),
                              ),
                            ),
                            for (final node in layout.nodes)
                              Positioned(
                                left: node.rect.left,
                                top: node.rect.top,
                                width: node.rect.width,
                                height: node.rect.height,
                                child: _ConceptNodeTile(
                                  label: node.concept.label,
                                  isRoot: node.isRoot,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: SizedBox(
        width: 42,
        height: 38,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: AppColors.partyPurple,
            side: const BorderSide(color: AppColors.softGray),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}

class _ConceptNodeTile extends StatelessWidget {
  const _ConceptNodeTile({required this.label, required this.isRoot});

  final String label;
  final bool isRoot;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isRoot ? AppColors.blueTint : AppColors.white,
        border: Border.all(
          color: AppColors.partyPurple,
          width: isRoot ? 1.6 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withAlpha(14),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Directionality(
        textDirection: _textDirection(label),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: isRoot ? 16 : 14,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

class _ConceptMapLayout {
  const _ConceptMapLayout({
    required this.width,
    required this.height,
    required this.nodes,
    required this.edges,
  });

  factory _ConceptMapLayout.from(ConceptMap conceptMap) {
    const nodeWidth = 190.0;
    const nodeHeight = 66.0;
    const horizontalGap = 34.0;
    const verticalGap = 92.0;
    const margin = 32.0;

    final conceptById = {
      for (final concept in conceptMap.concepts) concept.id: concept,
    };
    final childrenById = <String, List<String>>{};
    final incoming = <String>{};

    for (final relationship in conceptMap.relationships) {
      if (!conceptById.containsKey(relationship.from) ||
          !conceptById.containsKey(relationship.to)) {
        continue;
      }
      childrenById
          .putIfAbsent(relationship.from, () => [])
          .add(relationship.to);
      incoming.add(relationship.to);
    }

    final roots = conceptMap.concepts
        .where((concept) => !incoming.contains(concept.id))
        .map((concept) => concept.id)
        .toList();
    if (roots.isEmpty && conceptMap.concepts.isNotEmpty) {
      roots.add(conceptMap.concepts.first.id);
    }

    final levels = <List<String>>[];
    final visited = <String>{};
    var current = roots;
    while (current.isNotEmpty) {
      final level = current.where((id) => visited.add(id)).toList();
      if (level.isEmpty) {
        break;
      }
      levels.add(level);
      current = [
        for (final id in level) ...childrenById[id] ?? const <String>[],
      ];
    }

    final leftovers = conceptMap.concepts
        .where((concept) => !visited.contains(concept.id))
        .map((concept) => concept.id)
        .toList();
    if (leftovers.isNotEmpty) {
      levels.add(leftovers);
    }

    final maxLevelCount = levels.fold<int>(
      1,
      (max, level) => level.length > max ? level.length : max,
    );
    final width =
        margin * 2 +
        maxLevelCount * nodeWidth +
        (maxLevelCount - 1) * horizontalGap;
    final height =
        margin * 2 +
        levels.length * nodeHeight +
        (levels.length - 1) * verticalGap;

    final nodes = <_ConceptNode>[];
    for (var levelIndex = 0; levelIndex < levels.length; levelIndex += 1) {
      final level = levels[levelIndex];
      final levelWidth =
          level.length * nodeWidth + (level.length - 1) * horizontalGap;
      final startX = (width - levelWidth) / 2;
      final top = margin + levelIndex * (nodeHeight + verticalGap);

      for (var index = 0; index < level.length; index += 1) {
        final concept = conceptById[level[index]];
        if (concept == null) {
          continue;
        }
        nodes.add(
          _ConceptNode(
            concept: concept,
            rect: Rect.fromLTWH(
              startX + index * (nodeWidth + horizontalGap),
              top,
              nodeWidth,
              nodeHeight,
            ),
            isRoot: roots.contains(concept.id),
          ),
        );
      }
    }

    final nodeById = {for (final node in nodes) node.concept.id: node};
    final edges = [
      for (final relationship in conceptMap.relationships)
        if (nodeById[relationship.from] != null &&
            nodeById[relationship.to] != null)
          _ConceptEdge(
            from: nodeById[relationship.from]!,
            to: nodeById[relationship.to]!,
            label: relationship.type.replaceAll('_', ' '),
          ),
    ];

    return _ConceptMapLayout(
      width: width,
      height: height,
      nodes: nodes,
      edges: edges,
    );
  }

  final double width;
  final double height;
  final List<_ConceptNode> nodes;
  final List<_ConceptEdge> edges;
}

class _ConceptNode {
  const _ConceptNode({
    required this.concept,
    required this.rect,
    required this.isRoot,
  });

  final Concept concept;
  final Rect rect;
  final bool isRoot;
}

class _ConceptEdge {
  const _ConceptEdge({
    required this.from,
    required this.to,
    required this.label,
  });

  final _ConceptNode from;
  final _ConceptNode to;
  final String label;
}

class _ConceptMapPainter extends CustomPainter {
  const _ConceptMapPainter(this.layout);

  final _ConceptMapLayout layout;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.mutedText.withAlpha(150)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    for (final edge in layout.edges) {
      final start = Offset(edge.from.rect.center.dx, edge.from.rect.bottom);
      final end = Offset(edge.to.rect.center.dx, edge.to.rect.top);
      final midY = start.dy + (end.dy - start.dy) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(start.dx, midY)
        ..lineTo(end.dx, midY)
        ..lineTo(end.dx, end.dy);
      canvas.drawPath(path, linePaint);

      final labelPainter = TextPainter(
        text: TextSpan(
          text: edge.label,
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 120);
      labelPainter.paint(
        canvas,
        Offset(
          ((start.dx + end.dx) / 2) - (labelPainter.width / 2),
          midY - labelPainter.height - 4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConceptMapPainter oldDelegate) {
    return oldDelegate.layout != layout;
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

TextDirection _textDirection(String value) {
  return RegExp(r'[\u0600-\u06ff]').hasMatch(value)
      ? TextDirection.rtl
      : TextDirection.ltr;
}
