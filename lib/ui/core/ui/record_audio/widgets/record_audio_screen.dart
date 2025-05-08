import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:mobile_speech_recognition/ui/core/ui/record_audio/view_models/audio_recording_view_model.dart';
import 'package:mobile_speech_recognition/ui/core/ui/record_audio/widgets/save_audio_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class RecordAudioScreen extends StatefulWidget {
  const RecordAudioScreen({super.key});

  @override
  State<RecordAudioScreen> createState() => _RecordAudioScreenState();
}

class _RecordAudioScreenState extends State<RecordAudioScreen> {
  late AudioRecordingViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = AudioRecordingViewModel();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: viewModel,
      child: Consumer<AudioRecordingViewModel>(
        builder: (context, model, child) {
          final colorScheme = Theme.of(context).colorScheme;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Timer display section
              CreateTimerDisplaySection(context, model, colorScheme),

              // Waveform visualization section
              CreateWaveFormVisualizationSection(model, colorScheme, context),

              // Control buttons section
              CreatePlayerButtonsSection(
                model: model,
                onCancel: _showCancelConfirmationDialog,
                onSave: () async {
                  // Only allow save if recording has started
                  if (model.hasStartedRecording) {
                    if (model.isRecording) {
                      await model.pauseRecording();
                    }
                    
                    // Show the save dialog
                    if (model.recordedFilePath != null) {
                      await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return ChangeNotifierProvider.value(
                            value: model, // Pass the same ViewModel
                            child: SaveAudioDialog(),
                          );
                        },
                      );
                    }
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
        },
      ),
    );
  }

  Widget CreateTimerDisplaySection(
    BuildContext context,
    AudioRecordingViewModel model,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Large timer display
          Text(
            model.formatDuration(model.remainingSeconds),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),

          // Recording status
          if (model.hasStartedRecording)
            Text(
              model.isCompleted
                  ? "Recording completed"
                  : (model.isPaused ? "Paused" : "Recording"),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: model.isCompleted
                    ? colorScheme.secondary
                    : (model.isPaused ? colorScheme.error : colorScheme.primary),
                fontWeight: FontWeight.w500,
              ),
            ),

          // Show "Tap to start recording" if never started
          if (!model.hasStartedRecording)
            Text(
              "Tap the microphone to start recording",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget CreateWaveFormVisualizationSection(
    AudioRecordingViewModel model,
    ColorScheme colorScheme,
    BuildContext context,
  ) {
    // Calculate an appropriate height based on screen size
    final screenHeight = MediaQuery.of(context).size.height;
    final waveformHeight = (screenHeight * 0.25).clamp(150.0, 300.0);

    return Container(
      width: double.infinity,
      height: waveformHeight,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: AudioWaveforms(
        size: Size(MediaQuery.of(context).size.width, waveformHeight),
        recorderController: model.recorderController,
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
    );
  }

  Future<void> _showCancelConfirmationDialog() async {
    // If recording hasn't started, just close without confirmation
    if (!viewModel.hasStartedRecording) {
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
                // Reset recording and exit
                await viewModel.resetRecording();
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

// Add this to the RecordAudioScreen class
class CreatePlayerButtonsSection extends StatelessWidget {
  final AudioRecordingViewModel model;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const CreatePlayerButtonsSection({
    Key? key,
    required this.model,
    required this.onCancel,
    required this.onSave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Define button sizes
    const double sideButtonSize = 64;
    const double centerButtonSize = 80;

    // Uniform button style for delete and save
    final Color sideButtonColor = colorScheme.surfaceVariant;
    final Color sideButtonActiveColor = colorScheme.primaryContainer;
    final Color sideButtonIconColor = colorScheme.onSurfaceVariant;
    final Color sideButtonActiveIconColor = colorScheme.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end, // Align bottoms of all children
        children: [
          // Delete button with label - in a column for the label
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: sideButtonSize,
                height: sideButtonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sideButtonActiveColor,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: sideButtonIconColor,
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

          // Center button with different states
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  width: centerButtonSize,
                  height: centerButtonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: model.isCompleted
                        ? colorScheme.secondary
                        : model.isRecording
                            ? colorScheme.error
                            : colorScheme.primary,
                  ),
                  child: IconButton(
                    icon: _getCenterButtonIcon(model, colorScheme),
                    onPressed: () async {
                      if (model.isCompleted) {
                        // Restart recording if completed
                        await model.restartRecording(context);
                      } else if (model.hasStartedRecording) {
                        // Pause/resume if already started
                        await model.pauseRecording();
                      } else {
                        // Start new recording
                        await model.startRecording(context);
                      }
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              // Rerecord label for the refresh button
              if (model.isCompleted)
                Text(
                  'Rerecord',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
            ],
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
                  color: model.hasStartedRecording
                      ? sideButtonActiveColor
                      : sideButtonColor,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.check,
                    color: model.hasStartedRecording
                        ? sideButtonActiveIconColor
                        : sideButtonIconColor.withOpacity(0.5),
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
                  color: model.hasStartedRecording
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to get the appropriate icon for the center button
  Widget _getCenterButtonIcon(AudioRecordingViewModel model, ColorScheme colorScheme) {
    if (model.isCompleted) {
      // Show refresh icon for completed recordings
      return Icon(
        Icons.refresh,
        color: colorScheme.onSecondary,
        size: 40,
      );
    } else if (!model.hasStartedRecording) {
      // Show mic icon for initial state (not started recording)
      return Icon(
        Icons.mic,
        color: colorScheme.onPrimary,
        size: 40,
      );
    } else if (model.isRecording) {
      // Show pause icon while recording
      return Icon(
        Icons.pause,
        color: colorScheme.onError,
        size: 40,
      );
    } else {
      // Show play icon when paused
      return Icon(
        Icons.play_arrow,
        color: colorScheme.onPrimary,
        size: 40,
      );
    }
  }
}