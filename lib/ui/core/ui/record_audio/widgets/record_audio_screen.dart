import 'package:flutter/material.dart';
import 'dart:async';

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

  // Maximum recording time (2 minutes as per requirements)
  final int _maxRecordingSeconds = 120;

  @override
  void initState() {
    super.initState();
    // Don't start recording automatically
    // Just initialize in paused state
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _isPaused = false;
      _hasStartedRecording = true; // User has started recording
    });

    _startTimer();

    // Here you would integrate with actual recording functionality
  }

  void _pauseRecording() {
    // Only allow pause if already recording
    if (!_isRecording) {
      _startRecording();
      return;
    }

    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _stopTimer();
    } else {
      _startTimer();
    }

    // Here you would pause/resume the actual recording
  }

  void _stopRecording() {
    _stopTimer();
    setState(() {
      _isRecording = false;
    });

    // Here you would stop the actual recording
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

    if (hours > 0) {
      return 'you can keep recording $hours hours $minutes minutes';
    } else {
      return 'you can keep recording $minutes minutes';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    int remainingSeconds = _maxRecordingSeconds - _recordingSeconds;

    return Column(
      children: [
        CreateTimerDisplaySection(context, remainingSeconds, colorScheme),

        // SECTION 2: Waveform visualization
        Expanded(
          child: CreateWaveFormVisualizationSection(colorScheme, context),
        ),

        // SECTION 3: Control buttons with perfect alignment
        CreatePlayerButtonsSection(
          isRecording: _isRecording,
          isPaused: _isPaused,
          hasStartedRecording: _hasStartedRecording,
          onCancel: _showCancelConfirmationDialog,
          onRecordPause: _pauseRecording,
          onSave: () {
            // Only allow save if recording has started
            if (_hasStartedRecording) {
              _stopRecording();
              // Here you would proceed to the metadata form
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        // Placeholder for waveform visualization
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // This would be replaced with actual waveform visualization
            Icon(
              Icons.graphic_eq,
              size: 80,
              color:
                  _isRecording && !_isPaused
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _hasStartedRecording
                  ? "Waveform Visualization"
                  : "Start recording to see waveform",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
              onPressed: () {
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
