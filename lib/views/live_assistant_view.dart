import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sporcle/app_colors.dart';
import 'package:sporcle/models/live_assistant.dart';
import 'package:sporcle/services/api_service.dart';

class LiveAssistantView extends StatefulWidget {
  const LiveAssistantView({super.key, ApiService? apiService})
    : _apiService = apiService;

  final ApiService? _apiService;

  @override
  State<LiveAssistantView> createState() => _LiveAssistantViewState();
}

class _LiveAssistantViewState extends State<LiveAssistantView> {
  static const Duration _audioStatsUpdateInterval = Duration(milliseconds: 500);

  late final ApiService _apiService;
  final TextEditingController _messageController = TextEditingController();
  final List<_ConversationEntry> _conversation = [];
  final _LiveAssistantAudioEngine _audioEngine = _LiveAssistantAudioEngine();

  LiveAssistantConfig? _config;
  LiveAssistantUpload? _upload;
  PlatformFile? _selectedFile;
  LiveAssistantSocket? _socket;
  StreamSubscription<LiveAssistantIncoming>? _socketSubscription;

  String _language = 'en';
  String _subject = 'general';
  String _assistantState = 'idle';
  String _status = 'Loading settings...';
  String? _error;
  bool _isLoadingConfig = true;
  bool _isUploading = false;
  bool _isConnecting = false;
  bool _isStartingAudio = false;
  bool _isReady = false;
  bool _isConnected = false;
  bool _isMicrophoneActive = false;
  bool _isAudioPlaybackReady = false;
  int _audioFrames = 0;
  int _audioBytes = 0;
  DateTime? _lastAudioStatsUpdate;
  int? _inputRate;
  int? _outputRate;

  @override
  void initState() {
    super.initState();
    _apiService = widget._apiService ?? ApiService();
    _loadConfig();
  }

  @override
  void dispose() {
    _messageController.dispose();
    unawaited(_stopAudioIO());
    unawaited(_socketSubscription?.cancel());
    unawaited(_socket?.close());
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoadingConfig = true;
      _error = null;
    });

    try {
      final config = await _apiService.getLiveAssistantConfig();
      if (!mounted) {
        return;
      }
      setState(() {
        _config = config;
        _language = config.languages.contains(_language)
            ? _language
            : config.languages.first;
        _subject = config.subjects.contains(_subject)
            ? _subject
            : config.subjects.first;
        _inputRate = config.inputSampleRate;
        _outputRate = config.outputSampleRate;
        _status = config.isBusy
            ? 'All live tutor slots are currently in use.'
            : 'Ready. Start speaking after connecting.';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _status = 'Could not load settings.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingConfig = false);
      }
    }
  }

  Future<void> _pickDocument() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'jpg',
        'jpeg',
        'png',
        'webp',
        'heic',
        'heif',
        'txt',
      ],
    );
    if (files.isEmpty) {
      return;
    }

    setState(() {
      _selectedFile = files.first;
      _upload = null;
      _error = null;
    });
  }

  Future<LiveAssistantUpload?> _uploadSelectedDocument() async {
    final selectedFile = _selectedFile;
    if (selectedFile == null) {
      return null;
    }

    setState(() {
      _isUploading = true;
      _status = 'Uploading document...';
      _error = null;
    });

    try {
      final bytes = await selectedFile.readAsBytes();
      final upload = await _apiService.uploadLiveAssistantDocument(
        filename: selectedFile.name,
        path: selectedFile.path,
        bytes: bytes,
      );
      if (mounted) {
        setState(() {
          _upload = upload;
          _status = upload.label;
        });
      }
      return upload;
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _status = 'Upload failed.';
        });
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _startCall() async {
    if (_config?.isBusy ?? false) {
      setState(
        () => _error = 'Every live tutor slot is in use. Try again soon.',
      );
      return;
    }

    setState(() {
      _isConnecting = true;
      _error = null;
      _status = 'Establishing connection...';
      _assistantState = 'connecting';
      _conversation
        ..clear()
        ..add(
          const _ConversationEntry.system(
            'Session started. You can type a message once the tutor is ready.',
          ),
        );
      _audioFrames = 0;
      _audioBytes = 0;
      _lastAudioStatsUpdate = null;
      _isMicrophoneActive = false;
      _isAudioPlaybackReady = false;
      _isStartingAudio = false;
    });

    await _stopAudioIO();
    await _closeSocket();
    if (!await _ensureMicrophonePermission()) {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
      return;
    }

    final upload = _upload ?? await _uploadSelectedDocument();
    if (_selectedFile != null && upload == null) {
      setState(() => _isConnecting = false);
      return;
    }

    try {
      final socket = _apiService.connectToLiveAssistant();
      await _socketSubscription?.cancel();
      _socket = socket;
      _socketSubscription = socket.messages.listen(
        _handleSocketMessage,
        onError: (error) {
          if (mounted) {
            setState(() {
              _error = error.toString();
              _status = 'Connection error.';
              _isConnected = false;
              _isReady = false;
              _isStartingAudio = false;
            });
          }
          unawaited(_stopAudioIO());
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _status = 'Disconnected.';
              _assistantState = 'ended';
              _isConnected = false;
              _isReady = false;
              _isConnecting = false;
              _isStartingAudio = false;
            });
          }
          unawaited(_stopAudioIO());
        },
      );

      socket.sendOpening(
        LiveAssistantOpening(
          language: _language,
          subject: _subject,
          documentId: upload?.documentId,
          fileUri: upload?.uri,
          mimeType: upload?.mimeType,
        ),
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _isConnected = true;
        _status = 'Connected. Waiting for tutor audio session...';
      });
    } catch (error) {
      await _closeSocket();
      if (mounted) {
        setState(() {
          _error = error.toString();
          _status = 'Could not start the live session.';
          _assistantState = 'idle';
          _isConnected = false;
          _isReady = false;
          _isMicrophoneActive = false;
          _isAudioPlaybackReady = false;
          _isStartingAudio = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  void _handleSocketMessage(LiveAssistantIncoming event) {
    if (!mounted) {
      return;
    }

    if (event.type == 'audio') {
      final bytes = event.audio;
      if (bytes == null) {
        return;
      }

      _audioFrames += 1;
      _audioBytes += bytes.length;
      _queueAssistantAudio(bytes);
      _updateAudioStatsIfNeeded();
      return;
    }

    var shouldStartAudio = false;
    setState(() {
      switch (event.type) {
        case 'status':
          _isReady = event.message == 'ready';
          _inputRate = event.inputSampleRate ?? _inputRate;
          _outputRate = event.outputSampleRate ?? _outputRate;
          _status = _isReady
              ? 'Ready. Start speaking!'
              : event.message ?? 'Status update';
          if (_isReady) {
            shouldStartAudio = true;
          }
        case 'state':
          _assistantState = event.state ?? 'unknown';
          _status = _stateStatus(_assistantState);
        case 'text':
          final text = event.text;
          if (text != null) {
            _conversation.add(_ConversationEntry.assistant(text));
          }
        case 'notice':
          _conversation.add(
            _ConversationEntry.system(event.message ?? 'Session notice.'),
          );
          _status = event.message ?? 'Session notice.';
        case 'error':
          _error = _socketErrorMessage(event);
          _conversation.add(_ConversationEntry.system(_error!));
          _status = 'The tutor reported an error.';
        case 'turn_complete':
          _conversation.add(
            const _ConversationEntry.system('Tutor turn complete.'),
          );
        default:
          _conversation.add(
            const _ConversationEntry.system('Unknown server message.'),
          );
      }
    });

    if (shouldStartAudio) {
      unawaited(_startAudioWhenReady());
    }
  }

  void _updateAudioStatsIfNeeded() {
    final lastUpdate = _lastAudioStatsUpdate;
    final now = DateTime.now();
    if (lastUpdate != null &&
        now.difference(lastUpdate) < _audioStatsUpdateInterval) {
      return;
    }

    _lastAudioStatsUpdate = now;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _endCall() async {
    await _stopAudioIO();
    await _closeSocket();
    if (!mounted) {
      return;
    }
    setState(() {
      _socket = null;
      _socketSubscription = null;
      _isConnected = false;
      _isReady = false;
      _assistantState = 'ended';
      _status = 'Call ended.';
      _isMicrophoneActive = false;
      _isAudioPlaybackReady = false;
      _isStartingAudio = false;
    });
  }

  Future<void> _closeSocket() async {
    final subscription = _socketSubscription;
    final socket = _socket;
    _socketSubscription = null;
    _socket = null;
    await subscription?.cancel();
    await socket?.close();
  }

  Future<bool> _ensureMicrophonePermission() async {
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      if (mounted) {
        setState(() {
          _error = 'Microphone permission is required for the live call.';
          _status = 'Microphone blocked.';
        });
      }
      return false;
    }
    return true;
  }

  Future<void> _startAudioWhenReady() async {
    if (_isStartingAudio || _isMicrophoneActive || !_isConnected || !_isReady) {
      return;
    }

    final socket = _socket;
    if (socket == null) {
      return;
    }

    setState(() {
      _isStartingAudio = true;
      _status = 'Starting microphone...';
    });

    try {
      await _startAudioIO(socket);
    } catch (error) {
      await _closeSocket();
      if (mounted) {
        setState(() {
          _error = 'Audio could not start: $error';
          _status = 'Audio setup failed.';
          _assistantState = 'idle';
          _isConnected = false;
          _isReady = false;
          _isMicrophoneActive = false;
          _isAudioPlaybackReady = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingAudio = false);
      }
    }
  }

  Future<void> _startAudioIO(LiveAssistantSocket socket) async {
    final inputRate = _inputRate ?? _config?.inputSampleRate ?? 16000;
    final outputRate = _outputRate ?? _config?.outputSampleRate ?? 24000;

    try {
      await _audioEngine.start(
        inputSampleRate: inputRate,
        outputSampleRate: outputRate,
        onMicrophoneAudio: socket.sendAudio,
        onMicrophoneError: (error) {
          if (!mounted) {
            return;
          }
          setState(() {
            _error = 'Microphone stream stopped: $error';
            _status = 'Microphone stream stopped.';
            _isMicrophoneActive = false;
          });
        },
        onPlaybackError: (error) {
          if (!mounted) {
            return;
          }
          setState(() {
            _error = 'Tutor audio playback stopped: $error';
            _status = 'Audio playback stopped.';
            _isAudioPlaybackReady = false;
          });
        },
      );

      if (mounted) {
        setState(() {
          _isMicrophoneActive = true;
          _isAudioPlaybackReady = true;
          _status = _isReady ? 'Ready. Start speaking!' : _status;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Audio could not start: $error';
          _status = 'Audio setup failed.';
          _isMicrophoneActive = false;
          _isAudioPlaybackReady = false;
        });
      }
      rethrow;
    }
  }

  Future<void> _stopAudioIO() async {
    await _audioEngine.stop();
  }

  void _queueAssistantAudio(Uint8List bytes) {
    if (!_isAudioPlaybackReady) {
      return;
    }

    _audioEngine.enqueueAssistantAudio(bytes);
  }

  void _sendText() {
    final text = _messageController.text.trim();
    final socket = _socket;
    if (text.isEmpty || socket == null || !_canSendText) {
      return;
    }

    socket.sendText(text);
    setState(() {
      _conversation.add(_ConversationEntry.student(text));
      _messageController.clear();
      _status = 'Message sent.';
    });
  }

  bool get _canSendText {
    return _isConnected &&
        _isReady &&
        (_assistantState == 'listening' ||
            _assistantState == 'hearing' ||
            _assistantState == 'idle' ||
            _assistantState == 'connecting');
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
                  'Live Assistant',
                  style: textTheme.headlineMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Have a real-time tutoring session with Gemini. Upload a document to discuss it directly.',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.mutedText,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),
                _SessionSetupCard(
                  config: _config,
                  language: _language,
                  subject: _subject,
                  selectedFile: _selectedFile,
                  upload: _upload,
                  isLoadingConfig: _isLoadingConfig,
                  isUploading: _isUploading,
                  isConnecting: _isConnecting,
                  isConnected: _isConnected,
                  error: _error,
                  onLanguageChanged: (value) {
                    if (value != null) {
                      setState(() => _language = value);
                    }
                  },
                  onSubjectChanged: (value) {
                    if (value != null) {
                      setState(() => _subject = value);
                    }
                  },
                  onPickDocument: _pickDocument,
                  onStartCall: _isLoadingConfig || _isConnecting || _isConnected
                      ? null
                      : _startCall,
                  onEndCall: _isConnected ? _endCall : null,
                  onRetryConfig: _loadConfig,
                ),
                const SizedBox(height: 22),
                _LiveStatusCard(
                  status: _status,
                  assistantState: _assistantState,
                  isReady: _isReady,
                  isConnected: _isConnected,
                  isUploading: _isUploading,
                  inputRate: _inputRate,
                  outputRate: _outputRate,
                  audioFrames: _audioFrames,
                  audioBytes: _audioBytes,
                  isMicrophoneActive: _isMicrophoneActive,
                  isAudioPlaybackReady: _isAudioPlaybackReady,
                ),
                const SizedBox(height: 22),
                _AssistantStage(
                  assistantState: _assistantState,
                  isConnected: _isConnected,
                  audioFrames: _audioFrames,
                ),
                const SizedBox(height: 0),
                _ConversationPanel(
                  entries: _conversation,
                  messageController: _messageController,
                  canSendText: _canSendText,
                  onSendText: _sendText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionSetupCard extends StatelessWidget {
  const _SessionSetupCard({
    required this.config,
    required this.language,
    required this.subject,
    required this.selectedFile,
    required this.upload,
    required this.isLoadingConfig,
    required this.isUploading,
    required this.isConnecting,
    required this.isConnected,
    required this.error,
    required this.onLanguageChanged,
    required this.onSubjectChanged,
    required this.onPickDocument,
    required this.onStartCall,
    required this.onEndCall,
    required this.onRetryConfig,
  });

  final LiveAssistantConfig? config;
  final String language;
  final String subject;
  final PlatformFile? selectedFile;
  final LiveAssistantUpload? upload;
  final bool isLoadingConfig;
  final bool isUploading;
  final bool isConnecting;
  final bool isConnected;
  final String? error;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<String?> onSubjectChanged;
  final VoidCallback onPickDocument;
  final VoidCallback? onStartCall;
  final VoidCallback? onEndCall;
  final VoidCallback onRetryConfig;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final languages = config?.languages ?? const ['en'];
    final subjects = config?.subjects ?? const ['general'];
    final maxUploadMb = config?.maxUploadMb ?? 20;

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
                final isCompact = constraints.maxWidth < 660;
                return Wrap(
                  spacing: 20,
                  runSpacing: 14,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(
                      width: isCompact ? double.infinity : 150,
                      child: _LabeledField(
                        label: 'Language',
                        child: DropdownButtonFormField<String>(
                          initialValue: language,
                          isExpanded: true,
                          decoration: _inputDecoration(null),
                          items: languages
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(_languageLabel(item)),
                                ),
                              )
                              .toList(),
                          onChanged: isConnected ? null : onLanguageChanged,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: isCompact ? double.infinity : 210,
                      child: _LabeledField(
                        label: 'Subject',
                        child: DropdownButtonFormField<String>(
                          initialValue: subject,
                          isExpanded: true,
                          decoration: _inputDecoration(null),
                          items: subjects
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(_subjectLabel(item)),
                                ),
                              )
                              .toList(),
                          onChanged: isConnected ? null : onSubjectChanged,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Text(
              'Upload document',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: isConnected ? null : onPickDocument,
                  icon: const Icon(Icons.attach_file_rounded, size: 18),
                  label: const Text('Choose file'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.partyPurple,
                    side: const BorderSide(color: AppColors.softGray),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Text(
                  selectedFile?.name ?? 'No file chosen',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (upload != null)
                  _Pill(
                    upload!.kind.toUpperCase(),
                    color: const Color(0xFF20C77A),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'The tutor instructions are created by the server. Files can be PDF, image, WebP, HEIC, HEIF, or plain text up to $maxUploadMb MB.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.mutedText,
                height: 1.35,
                fontWeight: FontWeight.w700,
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
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 150,
                  child: FilledButton.icon(
                    onPressed: onStartCall,
                    icon: isConnecting || isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(Icons.call_rounded, size: 18),
                    label: Text(
                      isUploading
                          ? 'Uploading...'
                          : isConnecting
                          ? 'Starting...'
                          : 'Start call',
                    ),
                  ),
                ),
                if (isConnected)
                  SizedBox(
                    width: 130,
                    child: OutlinedButton.icon(
                      onPressed: onEndCall,
                      icon: const Icon(Icons.call_end_rounded, size: 18),
                      label: const Text('End call'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.softGray),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                if (isLoadingConfig)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (config == null)
                  TextButton(
                    onPressed: onRetryConfig,
                    child: const Text('Retry settings'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveStatusCard extends StatelessWidget {
  const _LiveStatusCard({
    required this.status,
    required this.assistantState,
    required this.isReady,
    required this.isConnected,
    required this.isUploading,
    required this.inputRate,
    required this.outputRate,
    required this.audioFrames,
    required this.audioBytes,
    required this.isMicrophoneActive,
    required this.isAudioPlaybackReady,
  });

  final String status;
  final String assistantState;
  final bool isReady;
  final bool isConnected;
  final bool isUploading;
  final int? inputRate;
  final int? outputRate;
  final int audioFrames;
  final int audioBytes;
  final bool isMicrophoneActive;
  final bool isAudioPlaybackReady;

  @override
  Widget build(BuildContext context) {
    final progressValue = isConnected ? 1.0 : null;
    final rateText = inputRate == null || outputRate == null
        ? 'Rates pending'
        : 'Mic $inputRate Hz / tutor $outputRate Hz';

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
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progressValue,
                backgroundColor: AppColors.softGray,
                color: const Color(0xFF20C77A),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    status,
                    style: TextStyle(
                      color: isReady ? const Color(0xFF148653) : AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _Pill(isConnected ? 'Connected' : 'Offline'),
              ],
            ),
            const SizedBox(height: 10),
            _StatusLine(
              label: isUploading ? 'Uploading document' : 'Document upload',
              trailing: isUploading ? 'In progress' : 'Optional',
            ),
            _StatusLine(
              label: 'WebSocket session',
              trailing: isConnected ? assistantState : 'Not started',
            ),
            _StatusLine(
              label: 'Microphone stream',
              trailing: isMicrophoneActive ? 'Sending audio' : 'Not active',
            ),
            _StatusLine(
              label: 'Tutor audio',
              trailing: !isAudioPlaybackReady
                  ? 'Not active'
                  : audioFrames == 0
                  ? 'Waiting'
                  : 'Playing $audioFrames frames, ${audioBytes ~/ 1024} KB',
            ),
            _StatusLine(label: 'Audio rates', trailing: rateText),
          ],
        ),
      ),
    );
  }
}

class _AssistantStage extends StatelessWidget {
  const _AssistantStage({
    required this.assistantState,
    required this.isConnected,
    required this.audioFrames,
  });

  final String assistantState;
  final bool isConnected;
  final int audioFrames;

  @override
  Widget build(BuildContext context) {
    final isSpeaking = assistantState == 'speaking';
    final title = !isConnected
        ? 'Start a session'
        : isSpeaking
        ? 'Speaking, please wait'
        : assistantState == 'thinking'
        ? 'Thinking'
        : 'Listening, go ahead';

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF142033),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withAlpha(28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: isSpeaking
                ? AppColors.partyPurple
                : const Color(0xFF20C77A),
            child: Icon(
              isSpeaking ? Icons.volume_up_rounded : Icons.mic_rounded,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (audioFrames > 0) ...[
            const SizedBox(height: 10),
            Text(
              '$audioFrames audio frames received',
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel({
    required this.entries,
    required this.messageController,
    required this.canSendText,
    required this.onSendText,
  });

  final List<_ConversationEntry> entries;
  final TextEditingController messageController;
  final bool canSendText;
  final VoidCallback onSendText;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      color: AppColors.midnight,
      shadowColor: AppColors.ink.withAlpha(18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
        side: BorderSide(color: AppColors.softGray),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          children: [
            SizedBox(
              height: 220,
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        'Session notes will appear here.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _ConversationBubble(entry: entries[index]);
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    enabled: canSendText,
                    decoration: _inputDecoration(
                      canSendText
                          ? 'Or type a message here...'
                          : 'Connect and wait for listening...',
                    ),
                    onSubmitted: (_) => onSendText(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 92,
                  child: FilledButton.icon(
                    onPressed: canSendText ? onSendText : null,
                    icon: const Icon(Icons.send_rounded, size: 17),
                    label: const Text('Send'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationBubble extends StatelessWidget {
  const _ConversationBubble({required this.entry});

  final _ConversationEntry entry;

  @override
  Widget build(BuildContext context) {
    final isStudent = entry.role == _ConversationRole.student;
    final isSystem = entry.role == _ConversationRole.system;

    return Align(
      alignment: isStudent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSystem
              ? AppColors.blueTint
              : isStudent
              ? AppColors.partyPurple
              : const Color(0xFFE8F2FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          entry.text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isStudent ? AppColors.white : AppColors.ink,
            height: 1.35,
            fontWeight: FontWeight.w700,
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

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.trailing});

  final String label;
  final String trailing;

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
          Text(
            trailing,
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

class _Pill extends StatelessWidget {
  const _Pill(this.label, {this.color = AppColors.partyPurple});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

typedef _AudioBytesHandler = void Function(Uint8List bytes);
typedef _AudioErrorHandler = void Function(Object error);

class _LiveAssistantAudioEngine {
  static const int _recorderBufferSize = 4096;
  static const int _playerBufferSize = 65536;
  static const int _maxPrebufferBytes = 96000;
  static const Duration _initialPrebuffer = Duration(milliseconds: 220);

  final List<Uint8List> _playbackQueue = [];

  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  StreamController<Uint8List>? _microphoneStreamController;
  StreamSubscription<Uint8List>? _microphoneSubscription;
  _AudioErrorHandler? _onPlaybackError;
  bool _hasStartedPlayback = false;
  bool _isStopping = false;
  int _queuedPlaybackBytes = 0;
  int _outputSampleRate = 24000;
  int _generation = 0;

  Future<void> start({
    required int inputSampleRate,
    required int outputSampleRate,
    required _AudioBytesHandler onMicrophoneAudio,
    required _AudioErrorHandler onMicrophoneError,
    required _AudioErrorHandler onPlaybackError,
  }) async {
    await stop();
    _generation += 1;
    final generation = _generation;
    _isStopping = false;
    _hasStartedPlayback = false;
    _onPlaybackError = onPlaybackError;
    _outputSampleRate = outputSampleRate;

    final player = FlutterSoundPlayer(logLevel: Level.error);
    final recorder = FlutterSoundRecorder(logLevel: Level.error);
    final streamController = StreamController<Uint8List>();
    StreamSubscription<Uint8List>? microphoneSubscription;

    try {
      await player.openPlayer();
      player.setLogLevel(Level.error);
      await player.startPlayerFromStream(
        codec: Codec.pcm16,
        interleaved: true,
        numChannels: 1,
        sampleRate: outputSampleRate,
        bufferSize: _playerBufferSize,
      );

      microphoneSubscription = streamController.stream.listen((bytes) {
        if (_isStopping || generation != _generation || bytes.isEmpty) {
          return;
        }
        try {
          onMicrophoneAudio(_pcm16Aligned(bytes));
        } catch (error) {
          onMicrophoneError(error);
        }
      }, onError: onMicrophoneError);

      await recorder.openRecorder();
      recorder.setLogLevel(Level.error);
      await recorder.startRecorder(
        codec: Codec.pcm16,
        toStream: streamController.sink,
        sampleRate: inputSampleRate,
        numChannels: 1,
        bufferSize: _recorderBufferSize,
        enableVoiceProcessing: true,
        enableNoiseSuppression: true,
        enableEchoCancellation: true,
      );

      if (generation != _generation || _isStopping) {
        await microphoneSubscription.cancel();
        await recorder.stopRecorder();
        await recorder.closeRecorder();
        await player.stopPlayer();
        await player.closePlayer();
        await streamController.close();
        return;
      }

      _player = player;
      _recorder = recorder;
      _microphoneStreamController = streamController;
      _microphoneSubscription = microphoneSubscription;
    } catch (error) {
      await microphoneSubscription?.cancel();
      await streamController.close();
      await recorder.closeRecorder();
      await player.closePlayer();
      _resetPlaybackQueue();
      rethrow;
    }
  }

  Future<void> stop() async {
    _generation += 1;
    _isStopping = true;
    final recorder = _recorder;
    final player = _player;
    final streamController = _microphoneStreamController;
    final microphoneSubscription = _microphoneSubscription;
    _recorder = null;
    _player = null;
    _microphoneStreamController = null;
    _microphoneSubscription = null;
    _onPlaybackError = null;
    _hasStartedPlayback = false;
    _resetPlaybackQueue();

    await microphoneSubscription?.cancel();
    if (recorder != null) {
      await recorder.stopRecorder();
      await recorder.closeRecorder();
    }
    await streamController?.close();
    if (player != null) {
      await player.stopPlayer();
      await player.closePlayer();
    }
  }

  void enqueueAssistantAudio(Uint8List bytes) {
    if (_isStopping || _player == null || bytes.isEmpty) {
      return;
    }

    final alignedBytes = _pcm16Aligned(bytes);
    if (alignedBytes.isEmpty) {
      return;
    }

    _playbackQueue.add(alignedBytes);
    _queuedPlaybackBytes += alignedBytes.length;

    if (!_hasStartedPlayback && _queuedPlaybackBytes < _initialPrebufferBytes) {
      if (_queuedPlaybackBytes > _maxPrebufferBytes) {
        _flushPlaybackQueue();
      }
      return;
    }

    _flushPlaybackQueue();
  }

  void _resetPlaybackQueue() {
    _playbackQueue.clear();
    _queuedPlaybackBytes = 0;
    _hasStartedPlayback = false;
  }

  int get _initialPrebufferBytes {
    final bytes =
        _outputSampleRate * 2 * _initialPrebuffer.inMilliseconds ~/ 1000;
    return bytes.isEven ? bytes : bytes + 1;
  }

  void _flushPlaybackQueue() {
    final player = _player;
    final sink = player?.uint8ListSink;
    if (_isStopping ||
        player == null ||
        sink == null ||
        _queuedPlaybackBytes == 0) {
      return;
    }

    final output = Uint8List(_queuedPlaybackBytes);
    var offset = 0;
    for (final chunk in _playbackQueue) {
      output.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    _playbackQueue.clear();
    _queuedPlaybackBytes = 0;
    _hasStartedPlayback = true;

    try {
      sink.add(output);
    } catch (error) {
      if (!_isStopping) {
        _onPlaybackError?.call(error);
      }
    }
  }

  Uint8List _pcm16Aligned(Uint8List bytes) {
    if (bytes.length.isEven) {
      return bytes;
    }
    return Uint8List.sublistView(bytes, 0, bytes.length - 1);
  }
}

class _ConversationEntry {
  const _ConversationEntry(this.role, this.text);

  const _ConversationEntry.assistant(String text)
    : this(_ConversationRole.assistant, text);

  const _ConversationEntry.student(String text)
    : this(_ConversationRole.student, text);

  const _ConversationEntry.system(String text)
    : this(_ConversationRole.system, text);

  final _ConversationRole role;
  final String text;
}

enum _ConversationRole { assistant, student, system }

String _stateStatus(String state) {
  return switch (state) {
    'listening' => 'Ready. Start speaking!',
    'hearing' => 'The tutor is hearing you.',
    'thinking' => 'The tutor is thinking.',
    'speaking' => 'The tutor is speaking.',
    _ => 'Session state: $state',
  };
}

String _socketErrorMessage(LiveAssistantIncoming event) {
  final message = event.message;
  return switch (event.reason) {
    'busy' => 'Every session on the server is in use. Try in a minute.',
    'too_many' => 'You already have a call open in another tab or device.',
    'rate_limit' => 'Too many attempts, or the daily quota is gone.',
    'no_opening' => 'The app failed to send the opening message.',
    'bad_request' => 'The opening message was not valid.',
    'config' => message ?? 'The server refused these session settings.',
    'unknown' => message ?? 'The server reported an unknown error.',
    _ => message ?? 'The live session could not continue.',
  };
}

String _languageLabel(String value) {
  return switch (value) {
    'en' => 'English',
    'ar' => 'Arabic',
    _ => value.toUpperCase(),
  };
}

String _subjectLabel(String value) {
  return switch (value) {
    'general' => 'Any subject',
    'puremath' => 'Pure math',
    _ =>
      value
          .split('_')
          .map(
            (word) => word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1)}',
          )
          .join(' '),
  };
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
