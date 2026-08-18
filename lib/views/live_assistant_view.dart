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
  bool _isConnected = false;
  bool _isReady = false;
  bool _audioReady = false;
  bool _microphoneOpen = false;
  int _inputRate = 16000;
  int _outputRate = 24000;
  int _audioFrames = 0;
  int _audioBytes = 0;

  @override
  void initState() {
    super.initState();
    _apiService = widget._apiService ?? ApiService();
    unawaited(_loadConfig());
  }

  @override
  void dispose() {
    _messageController.dispose();
    unawaited(_socketSubscription?.cancel());
    unawaited(_socket?.close());
    unawaited(_audioEngine.stop());
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoadingConfig = true;
      _error = null;
      _status = 'Loading settings...';
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
            ? 'All live tutor slots are currently busy.'
            : 'Ready to start a live tutoring session.';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _status = 'Could not load live assistant settings.';
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
      _status = 'Document selected. It will upload before the call.';
    });
  }

  Future<LiveAssistantUpload?> _uploadSelectedDocument() async {
    final file = _selectedFile;
    if (file == null) {
      return null;
    }

    setState(() {
      _isUploading = true;
      _error = null;
      _status = 'Uploading document...';
    });

    try {
      final upload = await _apiService.uploadLiveAssistantDocument(
        filename: file.name,
        path: file.path,
        bytes: file.path == null ? await file.readAsBytes() : null,
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
          _status = 'Document upload failed.';
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
    final config = _config;
    if (config == null) {
      await _loadConfig();
    }
    if (_config?.isBusy ?? false) {
      setState(() {
        _error = 'Every live tutor slot is in use. Try again in a minute.';
      });
      return;
    }

    if (!await _ensureMicrophonePermission()) {
      return;
    }

    setState(() {
      _isConnecting = true;
      _isConnected = false;
      _isReady = false;
      _audioReady = false;
      _microphoneOpen = false;
      _assistantState = 'connecting';
      _status = 'Starting live session...';
      _error = null;
      _audioFrames = 0;
      _audioBytes = 0;
      _conversation
        ..clear()
        ..add(
          const _ConversationEntry.system(
            'Session started. Speak when the tutor is listening, or type below.',
          ),
        );
    });

    await _closeSocket();
    await _audioEngine.stop();

    final upload = _upload ?? await _uploadSelectedDocument();
    if (_selectedFile != null && upload == null) {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
      return;
    }

    try {
      final socket = _apiService.connectToLiveAssistant();
      _socket = socket;
      _socketSubscription = socket.messages.listen(
        _handleSocketMessage,
        onError: (error) {
          if (!mounted) {
            return;
          }
          setState(() {
            _error = error.toString();
            _status = 'Connection error.';
            _isConnected = false;
            _isReady = false;
            _microphoneOpen = false;
          });
          unawaited(_audioEngine.stop());
        },
        onDone: () {
          if (!mounted) {
            return;
          }
          setState(() {
            _status = 'Call disconnected.';
            _assistantState = 'ended';
            _isConnected = false;
            _isReady = false;
            _isConnecting = false;
            _microphoneOpen = false;
          });
          unawaited(_audioEngine.stop());
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
        _status = 'Connected. Waiting for tutor readiness...';
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
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _endCall() async {
    await _audioEngine.stop();
    await _closeSocket();
    if (!mounted) {
      return;
    }
    setState(() {
      _isConnected = false;
      _isReady = false;
      _audioReady = false;
      _microphoneOpen = false;
      _assistantState = 'ended';
      _status = 'Call ended.';
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

  void _handleSocketMessage(LiveAssistantIncoming event) {
    if (!mounted) {
      return;
    }

    if (event.type == 'audio') {
      final bytes = event.audio;
      if (bytes == null || bytes.isEmpty) {
        return;
      }
      _audioFrames += 1;
      _audioBytes += bytes.length;
      _audioEngine.enqueueAssistantAudio(bytes);
      setState(() {});
      return;
    }

    var shouldStartAudio = false;
    var shouldUpdateMic = false;

    setState(() {
      switch (event.type) {
        case 'status':
          _isReady = event.message == 'ready';
          _inputRate = event.inputSampleRate ?? _inputRate;
          _outputRate = event.outputSampleRate ?? _outputRate;
          _language = event.language ?? _language;
          _subject = event.subject ?? _subject;
          _status = _isReady
              ? 'Ready. Waiting for your voice.'
              : event.message ?? 'Status update.';
          if (_isReady) {
            _assistantState = 'listening';
            shouldStartAudio = true;
            shouldUpdateMic = true;
          }
        case 'state':
          _assistantState = event.state ?? 'unknown';
          _status = _stateStatus(_assistantState);
          shouldUpdateMic = true;
        case 'text':
          final text = event.text;
          if (text != null) {
            _conversation.add(_ConversationEntry.assistant(text));
          }
        case 'notice':
          final message = event.message ?? 'Session notice.';
          _conversation.add(_ConversationEntry.system(message));
          _status = message;
        case 'error':
          final message = _socketErrorMessage(event);
          _error = message;
          _conversation.add(_ConversationEntry.system(message));
          _status = 'The tutor reported an error.';
        case 'turn_complete':
          _conversation.add(
            const _ConversationEntry.system('Tutor turn complete.'),
          );
          shouldUpdateMic = true;
        default:
          _conversation.add(
            const _ConversationEntry.system('Unknown server message.'),
          );
      }
    });

    if (shouldStartAudio) {
      unawaited(_startAudio());
    }
    if (shouldUpdateMic) {
      unawaited(_syncMicrophoneWithTurn());
    }
  }

  Future<void> _startAudio() async {
    final socket = _socket;
    if (socket == null || _audioReady) {
      return;
    }

    try {
      await _audioEngine.start(
        inputSampleRate: _inputRate,
        outputSampleRate: _outputRate,
        onMicrophoneAudio: socket.sendAudio,
        onMicrophoneChanged: (isOpen) {
          if (mounted) {
            setState(() => _microphoneOpen = isOpen);
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _error = error.toString();
              _status = 'Audio stopped unexpectedly.';
            });
          }
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _audioReady = true;
        _status = _stateStatus(_assistantState);
      });
      await _syncMicrophoneWithTurn();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Audio could not start: $error';
          _status = 'Audio setup failed.';
        });
      }
      await _endCall();
    }
  }

  Future<void> _syncMicrophoneWithTurn() async {
    if (!_audioReady || !_isConnected || !_isReady) {
      return;
    }
    final shouldOpen =
        _assistantState == 'listening' || _assistantState == 'hearing';
    if (shouldOpen) {
      await _audioEngine.openMicrophone();
    } else {
      await _audioEngine.closeMicrophone();
    }
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
        (_assistantState == 'listening' || _assistantState == 'hearing');
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
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.partyPurple,
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
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
                  'Start a real-time tutoring call, optionally with a lesson file.',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.mutedText,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                _SetupCard(
                  config: _config,
                  language: _language,
                  subject: _subject,
                  selectedFile: _selectedFile,
                  upload: _upload,
                  error: _error,
                  isLoadingConfig: _isLoadingConfig,
                  isUploading: _isUploading,
                  isConnecting: _isConnecting,
                  isConnected: _isConnected,
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
                  onClearDocument: _isConnected
                      ? null
                      : () {
                          setState(() {
                            _selectedFile = null;
                            _upload = null;
                          });
                        },
                  onStart: _isLoadingConfig || _isConnecting || _isConnected
                      ? null
                      : _startCall,
                  onEnd: _isConnected ? _endCall : null,
                  onRetryConfig: _loadConfig,
                ),
                const SizedBox(height: 18),
                _StatusCard(
                  status: _status,
                  assistantState: _assistantState,
                  isConnected: _isConnected,
                  isReady: _isReady,
                  microphoneOpen: _microphoneOpen,
                  audioReady: _audioReady,
                  inputRate: _inputRate,
                  outputRate: _outputRate,
                  audioFrames: _audioFrames,
                  audioBytes: _audioBytes,
                ),
                const SizedBox(height: 18),
                _Stage(
                  assistantState: _assistantState,
                  isConnected: _isConnected,
                  microphoneOpen: _microphoneOpen,
                ),
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

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.config,
    required this.language,
    required this.subject,
    required this.selectedFile,
    required this.upload,
    required this.error,
    required this.isLoadingConfig,
    required this.isUploading,
    required this.isConnecting,
    required this.isConnected,
    required this.onLanguageChanged,
    required this.onSubjectChanged,
    required this.onPickDocument,
    required this.onClearDocument,
    required this.onStart,
    required this.onEnd,
    required this.onRetryConfig,
  });

  final LiveAssistantConfig? config;
  final String language;
  final String subject;
  final PlatformFile? selectedFile;
  final LiveAssistantUpload? upload;
  final String? error;
  final bool isLoadingConfig;
  final bool isUploading;
  final bool isConnecting;
  final bool isConnected;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<String?> onSubjectChanged;
  final VoidCallback onPickDocument;
  final VoidCallback? onClearDocument;
  final VoidCallback? onStart;
  final VoidCallback? onEnd;
  final VoidCallback onRetryConfig;

  @override
  Widget build(BuildContext context) {
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
                final isCompact = constraints.maxWidth < 720;
                final fieldWidth = isCompact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 16) / 2;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: _LabeledField(
                        label: 'Language',
                        child: DropdownButtonFormField<String>(
                          initialValue: language,
                          isExpanded: true,
                          decoration: _inputDecoration(null),
                          items: languages
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(_languageLabel(value)),
                                ),
                              )
                              .toList(),
                          onChanged: isConnected ? null : onLanguageChanged,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _LabeledField(
                        label: 'Subject',
                        child: DropdownButtonFormField<String>(
                          initialValue: subject,
                          isExpanded: true,
                          decoration: _inputDecoration(null),
                          items: subjects
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(_subjectLabel(value)),
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
            _DocumentBox(
              selectedFile: selectedFile,
              upload: upload,
              maxUploadMb: maxUploadMb,
              isUploading: isUploading,
              isConnected: isConnected,
              onPickDocument: onPickDocument,
              onClearDocument: onClearDocument,
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
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isConnected ? onEnd : onStart,
                    icon: Icon(
                      isConnected ? Icons.call_end_rounded : Icons.mic_rounded,
                      size: 18,
                    ),
                    label: Text(
                      isConnected
                          ? 'End call'
                          : isUploading
                          ? 'Uploading...'
                          : isConnecting
                          ? 'Connecting...'
                          : 'Start live call',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: isConnected
                          ? AppColors.danger
                          : AppColors.partyPurple,
                    ),
                  ),
                ),
                if (isLoadingConfig) ...[
                  const SizedBox(width: 14),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ] else if (config == null) ...[
                  const SizedBox(width: 14),
                  TextButton(
                    onPressed: onRetryConfig,
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentBox extends StatelessWidget {
  const _DocumentBox({
    required this.selectedFile,
    required this.upload,
    required this.maxUploadMb,
    required this.isUploading,
    required this.isConnected,
    required this.onPickDocument,
    required this.onClearDocument,
  });

  final PlatformFile? selectedFile;
  final LiveAssistantUpload? upload;
  final int maxUploadMb;
  final bool isUploading;
  final bool isConnected;
  final VoidCallback onPickDocument;
  final VoidCallback? onClearDocument;

  @override
  Widget build(BuildContext context) {
    final file = selectedFile;
    final title = upload?.label ?? file?.name ?? 'No lesson selected';
    final detail = file == null
        ? 'Optional: PDF, image, or text up to $maxUploadMb MB.'
        : 'Selected for upload before the call';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blueTint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.softGray),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description_rounded,
            color: AppColors.partyPurple,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isUploading ? 'Uploading...' : detail,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            tooltip: 'Choose lesson',
            onPressed: isConnected ? null : onPickDocument,
            icon: const Icon(Icons.attach_file_rounded),
          ),
          if (file != null) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Remove lesson',
              onPressed: onClearDocument,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
    required this.assistantState,
    required this.isConnected,
    required this.isReady,
    required this.microphoneOpen,
    required this.audioReady,
    required this.inputRate,
    required this.outputRate,
    required this.audioFrames,
    required this.audioBytes,
  });

  final String status;
  final String assistantState;
  final bool isConnected;
  final bool isReady;
  final bool microphoneOpen;
  final bool audioReady;
  final int inputRate;
  final int outputRate;
  final int audioFrames;
  final int audioBytes;

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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 12),
            _StatusLine(label: 'Tutor state', trailing: assistantState),
            _StatusLine(
              label: 'Microphone',
              trailing: microphoneOpen ? 'Open' : 'Closed',
            ),
            _StatusLine(
              label: 'Audio playback',
              trailing: audioReady
                  ? '$audioFrames frames, ${audioBytes ~/ 1024} KB'
                  : 'Pending',
            ),
            _StatusLine(
              label: 'Sample rates',
              trailing: '$inputRate Hz input / $outputRate Hz output',
            ),
          ],
        ),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.assistantState,
    required this.isConnected,
    required this.microphoneOpen,
  });

  final String assistantState;
  final bool isConnected;
  final bool microphoneOpen;

  @override
  Widget build(BuildContext context) {
    final isSpeaking = assistantState == 'speaking';
    final isThinking = assistantState == 'thinking';
    final title = !isConnected
        ? 'Ready when you are'
        : isSpeaking
        ? 'Tutor is speaking'
        : isThinking
        ? 'Tutor is thinking'
        : microphoneOpen
        ? 'Listening now'
        : 'Waiting';

    return Container(
      height: 180,
      decoration: const BoxDecoration(
        color: Color(0xFF142033),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: isSpeaking
                ? AppColors.partyPurple
                : isThinking
                ? const Color(0xFFF0A01F)
                : const Color(0xFF20C77A),
            child: Icon(
              isSpeaking
                  ? Icons.volume_up_rounded
                  : isThinking
                  ? Icons.psychology_rounded
                  : Icons.mic_rounded,
              color: AppColors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
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
                        'Session messages will appear here.',
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
                          ? 'Type a message...'
                          : 'Wait for listening...',
                    ),
                    onSubmitted: (_) => onSendText(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 98,
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
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: Text(
              trailing,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.partyPurple.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.partyPurple,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

typedef _AudioBytesHandler = void Function(Uint8List bytes);
typedef _AudioErrorHandler = void Function(Object error);
typedef _MicrophoneStateHandler = void Function(bool isOpen);

class _LiveAssistantAudioEngine {
  static const int _recorderBufferSize = 3200;
  static const int _playerBufferSize = 65536;

  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  StreamController<Uint8List>? _microphoneStream;
  StreamSubscription<Uint8List>? _microphoneSubscription;
  _MicrophoneStateHandler? _onMicrophoneChanged;
  _AudioErrorHandler? _onError;
  bool _isStopping = false;
  bool _microphoneOpen = false;
  int _inputSampleRate = 16000;

  Future<void> start({
    required int inputSampleRate,
    required int outputSampleRate,
    required _AudioBytesHandler onMicrophoneAudio,
    required _MicrophoneStateHandler onMicrophoneChanged,
    required _AudioErrorHandler onError,
  }) async {
    await stop();
    _isStopping = false;
    _microphoneOpen = false;
    _inputSampleRate = inputSampleRate;
    _onMicrophoneChanged = onMicrophoneChanged;
    _onError = onError;

    final player = FlutterSoundPlayer(logLevel: Level.error);
    final recorder = FlutterSoundRecorder(logLevel: Level.error);
    final microphoneStream = StreamController<Uint8List>();
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

      microphoneSubscription = microphoneStream.stream.listen((bytes) {
        if (_isStopping || !_microphoneOpen || bytes.isEmpty) {
          return;
        }
        try {
          onMicrophoneAudio(_pcm16Aligned(bytes));
        } catch (error) {
          onError(error);
        }
      }, onError: onError);

      await recorder.openRecorder();
      recorder.setLogLevel(Level.error);

      _player = player;
      _recorder = recorder;
      _microphoneStream = microphoneStream;
      _microphoneSubscription = microphoneSubscription;
    } catch (_) {
      await microphoneSubscription?.cancel();
      await microphoneStream.close();
      await recorder.closeRecorder();
      await player.closePlayer();
      rethrow;
    }
  }

  Future<void> openMicrophone() async {
    final recorder = _recorder;
    final stream = _microphoneStream;
    if (_isStopping || recorder == null || stream == null || _microphoneOpen) {
      return;
    }

    await recorder.startRecorder(
      codec: Codec.pcm16,
      toStream: stream.sink,
      sampleRate: _inputSampleRate,
      numChannels: 1,
      bufferSize: _recorderBufferSize,
      enableVoiceProcessing: true,
      enableNoiseSuppression: true,
      enableEchoCancellation: true,
    );
    _microphoneOpen = true;
    _onMicrophoneChanged?.call(true);
  }

  Future<void> closeMicrophone() async {
    final recorder = _recorder;
    if (recorder == null || !_microphoneOpen) {
      return;
    }

    try {
      await recorder.stopRecorder();
    } catch (error) {
      if (!_isStopping) {
        _onError?.call(error);
      }
    } finally {
      _microphoneOpen = false;
      _onMicrophoneChanged?.call(false);
    }
  }

  void enqueueAssistantAudio(Uint8List bytes) {
    final sink = _player?.uint8ListSink;
    if (_isStopping || sink == null) {
      return;
    }

    final aligned = _pcm16Aligned(bytes);
    if (aligned.isEmpty) {
      return;
    }

    try {
      sink.add(aligned);
    } catch (error) {
      if (!_isStopping) {
        _onError?.call(error);
      }
    }
  }

  Future<void> stop() async {
    _isStopping = true;
    final recorder = _recorder;
    final player = _player;
    final stream = _microphoneStream;
    final subscription = _microphoneSubscription;

    _recorder = null;
    _player = null;
    _microphoneStream = null;
    _microphoneSubscription = null;
    _onMicrophoneChanged = null;
    _onError = null;
    _microphoneOpen = false;

    await subscription?.cancel();
    if (recorder != null) {
      if (!recorder.isStopped) {
        await recorder.stopRecorder();
      }
      await recorder.closeRecorder();
    }
    await stream?.close();
    if (player != null) {
      await player.stopPlayer();
      await player.closePlayer();
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
    'listening' => 'Listening. You can speak now.',
    'hearing' => 'The tutor is hearing you.',
    'thinking' => 'The tutor is thinking. Microphone is closed.',
    'speaking' => 'The tutor is speaking. Microphone is closed.',
    'connecting' => 'Connecting...',
    'idle' => 'Ready to start a live tutoring session.',
    'ended' => 'Call ended.',
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
