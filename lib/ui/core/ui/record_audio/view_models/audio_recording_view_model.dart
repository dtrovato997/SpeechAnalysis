import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:mobile_speech_recognition/data/repositories/audio_analysis_repository.dart';
import 'package:path_provider/path_provider.dart';

class AudioRecordingViewModel extends ChangeNotifier {
  // Controller for the waveform recording
  late RecorderController recorderController;

  // Audio file path
  String? recordedFilePath;

  // Title and description from SaveAudioDialog
  String Title = '';
  String? Description;

  // Recording state variables
  bool _isRecording = false;
  bool _isPaused = false;
  bool _hasStartedRecording = false;
  bool _isCompleted = false;

  // Timer related variables
  int remainingSeconds = 30; // Default 30 seconds max recording time
  int _elapsedSeconds = 0;
  static const int MAX_RECORDING_DURATION = 30; // 30 seconds max

  // Repository for saving analyses
  final AudioAnalysisRepository _audioAnalysisRepository =
      AudioAnalysisRepository();

  // Constructor
  AudioRecordingViewModel() {
    // Initialize recorder controller with default settings
    recorderController =
        RecorderController()
          ..androidEncoder = AndroidEncoder.aac
          ..androidOutputFormat = AndroidOutputFormat.mpeg4
          ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
          ..sampleRate = 44100;

    // Set up timer
    remainingSeconds = MAX_RECORDING_DURATION;
  }

  // Getters for recording state
  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  bool get hasStartedRecording => _hasStartedRecording;
  bool get isCompleted => _isCompleted;

  // Format duration as mm:ss
  String formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Start recording
  Future<void> startRecording(BuildContext context) async {
    try {
      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/temp_recording.aac';

      // Start recording
      await recorderController.record(path: filePath);

      // Update state
      _isRecording = true;
      _hasStartedRecording = true;
      _isPaused = false;
      recordedFilePath = filePath;

      // Start timer
      _startTimer();

      notifyListeners();
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting recording: $e')));
    }
  }

  // Pause or resume recording
  Future<void> pauseRecording() async {
    if (_isRecording) {
      // Pause
      await recorderController.pause();
      _isPaused = true;
      _isRecording = false;
    } else if (_isPaused) {
      // Resume
      await recorderController.record();
      _isPaused = false;
      _isRecording = true;
    }
    notifyListeners();
  }

  // Reset recording
  Future<void> resetRecording() async {
    await recorderController.stop();

    // Reset all states
    _isRecording = false;
    _isPaused = false;
    _hasStartedRecording = false;
    _isCompleted = false;
    _elapsedSeconds = 0;
    remainingSeconds = MAX_RECORDING_DURATION;

    notifyListeners();
  }

  // Restart recording
  Future<void> restartRecording(BuildContext context) async {
    await resetRecording();
    await startRecording(context);
  }

  // Timer for recording
  void _startTimer() {
    // Set up a periodic timer that updates every second
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording) {
        _elapsedSeconds++;
        remainingSeconds = (MAX_RECORDING_DURATION - _elapsedSeconds).clamp(
          0,
          MAX_RECORDING_DURATION,
        );

        // Check if recording time is up
        if (remainingSeconds <= 0) {
          _completeRecording();
        } else {
          // Continue timer if still recording
          notifyListeners();
          _startTimer();
        }
      }
    });
  }

  // Complete recording when time is up
  void _completeRecording() async {
    await recorderController.stop();
    _isRecording = false;
    _isPaused = false;
    _isCompleted = true;
    notifyListeners();
  }

  // Save recording - this will be called from the SaveAudioDialog
  Future<void> saveRecording() async {
    try {
      if (recordedFilePath == null) {
        print('No recording to save');
        return;
      }

      if (Title.isEmpty) {
        print('Title cant be empty');
        return;
      }

      // Create a new audio analysis
      await _audioAnalysisRepository.createAnalysis(
        title:
            Title.isEmpty
                ? 'Recording_${DateTime.now().millisecondsSinceEpoch}'
                : Title,
        description: Description,
        recordingPath: recordedFilePath!,
      );
      // Mark as completed
      _isCompleted = true;
      notifyListeners();
    } catch (e) {
      print('Error saving recording: $e');
      // TODO: Handle error appropriately
    }
  }

  // Clean up resources
  @override
  void dispose() {
    recorderController.dispose();
    super.dispose();
  }
}
