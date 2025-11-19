import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:mobile_speech_recognition/ui/core/ui/record_audio/view_models/audio_recording_view_model.dart';
import 'package:mobile_speech_recognition/ui/core/save_audio_dialog.dart';
import 'package:mobile_speech_recognition/ui/core/ui/analysis_detail/widgets/audio_analysis_detail_screen.dart';
import 'package:mobile_speech_recognition/services/logger_service.dart';
import 'package:provider/provider.dart';

class RecordAudioScreen extends StatefulWidget {
  const RecordAudioScreen({super.key});

  @override
  State<RecordAudioScreen> createState() => _RecordAudioScreenState();
}

class _RecordAudioScreenState extends State<RecordAudioScreen> {
  final _logger = LoggerService();
  late AudioRecordingViewModel viewModel;

  @override
  void initState() {
    super.initState();
    _logger.info('RecordAudioScreen initialized');
    viewModel = AudioRecordingViewModel(context);
  }

  @override
  void dispose() {
    _logger.debug('RecordAudioScreen disposing');
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
                  if (model.hasStartedRecording) {
                    _logger.info('Save button pressed - pausing recording if active');
                    
                    if (model.isRecording) {
                      await model.pauseRecording();
                    }
                    
                    // Show the generic save dialog
                    if (model.recordedFilePath != null) {
                      await _showSaveDialog(model);
                    } else {
                      _logger.warning('Cannot save: recorded file path is null');
                    }
                  } else {
                    _logger.warning('Save button pressed but no recording has been started');
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
      _logger.debug('Cancel pressed without recording, closing screen');
      Navigator.pop(context);
      return;
    }

    _logger.info('Showing cancel confirmation dialog');
    
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
              onPressed: () {
                _logger.debug('User chose not to cancel recording');
                Navigator.of(context).pop();
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () async {
                _logger.info('User confirmed cancellation, discarding recording');
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

  Future<void> _showSaveDialog(AudioRecordingViewModel model) async {
    _logger.info('Showing save dialog');
    
    final SaveAudioResult? result = await showDialog<SaveAudioResult>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return SaveAudioDialog.forRecording();
      },
    );

    if (result != null) {
      _logger.info('Save dialog completed - Title: "${result.title}", Has description: ${result.description != null && result.description!.isNotEmpty}');
      
      // Set the title and description in the view model
      model.Title = result.title;
      model.Description = result.description;

      try {
        _logger.info('Saving recording to repository');
        // Save the recording
        final analysis = await model.saveRecording();

        if (analysis != null) {
          _logger.info('Recording saved successfully - ID: ${analysis.id}');
          
          // Close the recording screen
          Navigator.pop(context);

          // Navigate to analysis detail
          _logger.debug('Navigating to analysis detail screen');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AudioAnalysisDetailScreen(
                analysisId: analysis.id!,
              ),
            ),
          );
        } else {
          _logger.error('Failed to save recording: saveRecording returned null');
          // Show error if save failed
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save recording'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e, stackTrace) {
        _logger.error('Error saving recording', e, stackTrace);
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving recording: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      _logger.debug('Save dialog cancelled by user');
    }
  }
}

// Add this to the RecordAudioScreen class
class CreatePlayerButtonsSection extends StatelessWidget {
  final _logger = LoggerService();
  final AudioRecordingViewModel model;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  CreatePlayerButtonsSection({
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
                  onPressed: () {
                    _logger.debug('Delete/Cancel button pressed');
                    onCancel();
                  },
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
                        _logger.info('Rerecord button pressed');
                        // Restart recording if completed
                        await model.restartRecording(context);
                      } else if (model.hasStartedRecording) {
                        _logger.info('Pause/Resume button pressed - Current state: ${model.isRecording ? "recording" : "paused"}');
                        // Pause/resume if already started
                        await model.pauseRecording();
                      } else {
                        _logger.info('Start recording button pressed');
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