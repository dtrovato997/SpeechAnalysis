import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:mobile_speech_recognition/data/repositories/audio_analysis_repository.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis/audio_analysis.dart';
import 'package:mobile_speech_recognition/services/logger_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class AudioRecordingViewModel extends ChangeNotifier {
  final _logger = LoggerService();

  // Controller for the waveform recording
  late RecorderController recorderController;

  // Audio file path
  String? recordedFilePath;

  // Title and description
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
  final AudioAnalysisRepository _audioAnalysisRepository;

  // Constructor
  AudioRecordingViewModel(BuildContext context) 
    : _audioAnalysisRepository = Provider.of<AudioAnalysisRepository>(context, listen: false) {
    _logger.info('AudioRecordingViewModel initialized');

    // Initialize recorder controller with default settings
    recorderController =
        RecorderController()
          ..androidEncoder = AndroidEncoder.aac
          ..androidOutputFormat = AndroidOutputFormat.mpeg4
          ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
          ..sampleRate = 16000// 16kHz sample rate
          ..bitRate = 256000; // 256 kbps bitrate

    _logger.debug('RecorderController configured - sampleRate: 16000, bitRate: 256000');

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
      _logger.info('Starting audio recording');
      
      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/temp_recording.m4a';
      
      _logger.debug('Recording path: $filePath');

      // Start recording
      await recorderController.record(path: filePath);

      // Update state
      _isRecording = true;
      _hasStartedRecording = true;
      _isPaused = false;
      recordedFilePath = filePath;

      _logger.info('Audio recording started successfully');

      // Start timer
      _startTimer();

      notifyListeners();
    } catch (e, stackTrace) {
      _logger.error('Error starting recording', e, stackTrace);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting recording: $e')));
    }
  }

  // Pause or resume recording
  Future<void> pauseRecording() async {
    try {
      if (_isRecording) {
        // Pause
        _logger.info('Pausing audio recording at ${_elapsedSeconds}s');
        await recorderController.pause();
        _isPaused = true;
        _isRecording = false;
        _logger.debug('Audio recording paused');
      } else if (_isPaused) {
        // Resume
        _logger.info('Resuming audio recording from ${_elapsedSeconds}s');
        await recorderController.record();
        _isPaused = false;
        _isRecording = true;
        _logger.debug('Audio recording resumed');
      }
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.error('Error pausing/resuming recording', e, stackTrace);
    }
  }

  // Reset recording
  Future<void> resetRecording() async {
    try {
      _logger.info('Resetting audio recording');
      await recorderController.stop();

      // Reset all states
      _isRecording = false;
      _isPaused = false;
      _hasStartedRecording = false;
      _isCompleted = false;
      _elapsedSeconds = 0;
      remainingSeconds = MAX_RECORDING_DURATION;

      _logger.debug('Audio recording reset complete');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.error('Error resetting recording', e, stackTrace);
    }
  }

  // Restart recording
  Future<void> restartRecording(BuildContext context) async {
    _logger.info('Restarting audio recording');
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

        if (_elapsedSeconds % 5 == 0) {
          _logger.debug('Recording progress: ${_elapsedSeconds}s elapsed, ${remainingSeconds}s remaining');
        }

        // Check if recording time is up
        if (remainingSeconds <= 0) {
          _logger.info('Recording time limit reached (${MAX_RECORDING_DURATION}s)');
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
    try {
      _logger.info('Completing audio recording at ${_elapsedSeconds}s');
      await recorderController.stop();
      _isRecording = false;
      _isPaused = false;
      _isCompleted = true;
      _logger.info('Audio recording completed successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.error('Error completing recording', e, stackTrace);
    }
  }

  // Save recording
  Future<AudioAnalysis?> saveRecording() async {
    try {
      _logger.info('Saving audio recording - Title: "$Title", Duration: ${_elapsedSeconds}s');
      
      await recorderController.stop();
      _isRecording = false;
      _isPaused = false;
      _isCompleted = true;

      if (recordedFilePath == null) {
        _logger.error('Cannot save recording: file path is null');
        return null;
      }

      if (Title.isEmpty) {
        _logger.warning('Cannot save recording: title is empty');
        return null;
      }

      // Check if file exists
      final file = File(recordedFilePath!);
      if (!await file.exists()) {
        _logger.error('Cannot save recording: file does not exist at path: $recordedFilePath');
        return null;
      }

      final fileSize = await file.length();
      _logger.debug('Recording file size: ${fileSize} bytes');

      // Create a new audio analysis
      _logger.info('Creating audio analysis in repository');
      AudioAnalysis result = await _audioAnalysisRepository.createAnalysis(
        title: Title,
        description: Description,
        recordingPath: recordedFilePath!,
      );

      _logger.info('Audio analysis created successfully - ID: ${result.id}, Path: ${result.recordingPath}');

      notifyListeners();

      return result;
    } catch (e, stackTrace) {
      _logger.error('Error saving recording', e, stackTrace);
      rethrow; 
    }
  }

  // Clean up resources
  @override
  void dispose() {
    _logger.info('Disposing AudioRecordingViewModel - Elapsed: ${_elapsedSeconds}s, Completed: $_isCompleted');
    recorderController.dispose();
    super.dispose();
  }
}