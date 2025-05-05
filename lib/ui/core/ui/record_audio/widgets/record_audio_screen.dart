import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class RecordAudioScreen extends StatefulWidget {
  const RecordAudioScreen({super.key});

  @override
  State<RecordAudioScreen> createState() => _RecordAudioScreenState();
}

class _RecordAudioScreenState extends State<RecordAudioScreen> {
  bool _isRecording = false;
  bool _isPaused = true; // Initially paused
  bool _hasStartedRecording = false; // Track if recording has ever started
  int _recordingSeconds = 0;
  Timer? _timer;
  late RecorderController recorderController;
  String? recordedFilePath;

  // Maximum recording time (2 minutes as per requirements)
  final int _maxRecordingSeconds = 30;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    // Initialize the recorder controller
    recorderController =
        RecorderController()
          ..androidEncoder = AndroidEncoder.aac
          ..androidOutputFormat = AndroidOutputFormat.mpeg4
          ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
          ..sampleRate = 44100
          ..bitRate = 128000;
      

    // Check microphone permission
    await recorderController.checkPermission();

    // Set the update frequency for waveform display
    recorderController.updateFrequency = const Duration(milliseconds: 100);
  }

  @override
  void dispose() {
    _stopTimer();
    recorderController.dispose();
    super.dispose();
  }

  Future<String> _getRecordingPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${appDir.path}/recording_$timestamp.m4a';
  }

  Future<void> _startRecording() async {
    if (!recorderController.hasPermission) {
      await recorderController.checkPermission();
      if (!recorderController.hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission not granted'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    final path = await _getRecordingPath();
    await recorderController.record(path: path);

    setState(() {
      _isRecording = true;
      _isPaused = false;
      _hasStartedRecording = true; // User has started recording
    });

    _startTimer();

    // Listen to current duration updates
    recorderController.onCurrentDuration.listen((duration) {
      // This could be used to update UI if needed
      // We already have a timer, but this could be used for more precision
    });
  }

  Future<void> _pauseRecording() async {
    // Only allow pause if already recording
    if (!_isRecording && !_hasStartedRecording) {
      await _startRecording();
      return;
    } else if (!_isRecording && _hasStartedRecording) {
      // Resume recording after it was paused
      await recorderController.record();
      setState(() {
        _isRecording = true;
        _isPaused = false;
      });
      _startTimer();
      return;
    }

    // Pause the current recording
    await recorderController.pause();

    setState(() {
      _isPaused = true;
      _isRecording = false;
    });

    _stopTimer();
  }

  Future<void> _stopRecording() async {
    _stopTimer();

    if (_isRecording || _hasStartedRecording) {
      recordedFilePath = await recorderController.stop();

      setState(() {
        _isRecording = false;
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_recordingSeconds < _maxRecordingSeconds) {
          _recordingSeconds++;
        } else {
          // Auto-stop at max duration
          _stopRecording();
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String _formatDuration(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    int milliseconds = 0; // In a real app, you'd track milliseconds too

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(2, '0')}';
  }

  String _formatRemainingTime(int secondsRemaining) {
    int hours = secondsRemaining ~/ 3600;
    int minutes = (secondsRemaining % 3600) ~/ 60;
    int seconds = secondsRemaining % 60;

    return 'you can keep recording $seconds seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    int remainingSeconds = _maxRecordingSeconds - _recordingSeconds;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CreateTimerDisplaySection(context, remainingSeconds, colorScheme),

        // SECTION 2: Waveform visualization
        CreateWaveFormVisualizationSection(colorScheme, context),

        // SECTION 3: Control buttons with perfect alignment
        CreatePlayerButtonsSection(
          isRecording: _isRecording,
          isPaused: _isPaused,
          hasStartedRecording: _hasStartedRecording,
          onCancel: _showCancelConfirmationDialog,
          onRecordPause: _pauseRecording,
          onSave: () async {
            // Only allow save if recording has started
            if (_hasStartedRecording) {
              await _stopRecording();
              // Here you would proceed to the metadata form
              if (recordedFilePath != null) {
                // You can add code here to handle the saved recording
                // For example, pass the file path to another screen
                print('Recording saved at: $recordedFilePath');
              }
              Navigator.pop(context);
            } else {
              // Show a message if trying to save without recording
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please record some audio first'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget CreateTimerDisplaySection(
    BuildContext context,
    int remainingSeconds,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Large timer display
          Text(
            _formatDuration(_recordingSeconds),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color:
                  remainingSeconds < 30
                      ? colorScheme.error
                      : colorScheme.onSurface,
            ),
          ),

          // Recording status - only show if recording has started
          if (_hasStartedRecording)
            Text(
              _isPaused ? "Paused" : "Recording",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _isPaused ? colorScheme.error : colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),

          // Show "Tap to start recording" if never started
          if (!_hasStartedRecording)
            Text(
              "Tap the microphone to start recording",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),

          // Remaining time
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _formatRemainingTime(remainingSeconds),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color:
                    remainingSeconds < 30
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget CreateWaveFormVisualizationSection(
    ColorScheme colorScheme,
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder:
            (context, constraints) => Center(
              child: AudioWaveforms(
                size: Size(constraints.maxWidth, constraints.maxHeight >= 300 ? 300 : constraints.maxHeight),
                recorderController: recorderController,
                backgroundColor: colorScheme.surfaceBright,
                waveStyle: WaveStyle(
                  waveColor: colorScheme.primary,
                  extendWaveform: true,
                  durationLinesHeight: 16.0,
                  showMiddleLine: false,
                  spacing: 5.0,
                  scaleFactor: 200,
                  waveThickness: 3,
                  showDurationLabel: true,
                  
                  durationLinesColor: colorScheme.onSurfaceVariant,
                  durationStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  
                ),
                
                enableGesture: true,
                shouldCalculateScrolledPosition: true,

              ),
            ),
      ),
    );
  }

  Future<void> _showCancelConfirmationDialog() async {
    // If recording hasn't started, just close without confirmation
    if (!_hasStartedRecording) {
      Navigator.pop(context);
      return;
    }

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Recording?'),
          content: const Text(
            'The recorded audio will be discarded. Do you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () async {
                // Stop recording and discard
                if (_isRecording) {
                  await recorderController.stop();
                }
                // Reset controller
                recorderController.refresh();

                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Exit recording screen
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }
}

// Buttons with aligned bottoms
class CreatePlayerButtonsSection extends StatelessWidget {
  final bool isRecording;
  final bool isPaused;
  final bool hasStartedRecording;
  final VoidCallback onCancel;
  final VoidCallback onRecordPause;
  final VoidCallback onSave;

  const CreatePlayerButtonsSection({
    Key? key,
    required this.isRecording,
    required this.isPaused,
    required this.hasStartedRecording,
    required this.onCancel,
    required this.onRecordPause,
    required this.onSave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Define button sizes
    const double sideButtonSize = 64;
    const double centerButtonSize = 80;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment:
            CrossAxisAlignment.end, // Align bottoms of all children
        children: [
          // Cancel button with label - in a column for the label
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: sideButtonSize,
                height: sideButtonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.errorContainer,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: colorScheme.onErrorContainer,
                    size: 32,
                  ),
                  onPressed: onCancel,
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Delete',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),

          // We add padding to ensure bottom alignment with the other buttons
          Padding(
            padding: const EdgeInsets.only(
              bottom: 24,
            ), // 8px for text + 16px for spacing in columns
            child: Container(
              width: centerButtonSize,
              height: centerButtonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isRecording
                        ? (isPaused ? colorScheme.primary : colorScheme.error)
                        : colorScheme.primary,
              ),
              child: IconButton(
                icon: Icon(
                  // Show mic icon if not actively recording (initial state or paused)
                  isPaused || !isRecording ? Icons.mic : Icons.pause,
                  color:
                      isRecording
                          ? (isPaused
                              ? colorScheme.onPrimary
                              : colorScheme.onError)
                          : colorScheme.onPrimary,
                  size: 40,
                ),
                onPressed: onRecordPause,
                padding: EdgeInsets.zero,
              ),
            ),
          ),

          // Save button with label
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: sideButtonSize,
                height: sideButtonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      hasStartedRecording
                          ? colorScheme.primaryContainer
                          : colorScheme
                              .surfaceVariant, // Dimmed if not started recording
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.check,
                    color:
                        hasStartedRecording
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant.withOpacity(
                              0.5,
                            ), // Dimmed if not started recording
                    size: 32,
                  ),
                  onPressed: onSave,
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Save',
                style: textTheme.bodyMedium?.copyWith(
                  color:
                      hasStartedRecording
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant.withOpacity(
                            0.5,
                          ), // Dimmed if not started recording
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
