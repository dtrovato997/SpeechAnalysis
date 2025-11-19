// lib/ui/core/ui/upload_audio/view_models/upload_audio_view_model.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/data/repositories/audio_analysis_repository.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis/audio_analysis.dart';
import 'package:mobile_speech_recognition/services/logger_service.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';

class UploadAudioViewModel extends ChangeNotifier {
  final _logger = LoggerService();
  
  // Repository for saving analyses
  final AudioAnalysisRepository _audioAnalysisRepository;
  
  // Audio player for duration checking
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Selected file path
  String? selectedFilePath;
  
  // Audio duration
  Duration? audioDuration;

  // Title and description from SaveAudioDialog
  String title = '';
  String? description;

  // Loading states
  bool _isPickingFile = false;
  bool _isCheckingDuration = false;
  bool _isSaving = false;

  // Error state
  String? _error;

  // Constructor
  UploadAudioViewModel(BuildContext context) 
    : _audioAnalysisRepository = Provider.of<AudioAnalysisRepository>(context, listen: false) {
    _logger.info('UploadAudioViewModel initialized');
  }

  // Getters
  bool get isPickingFile => _isPickingFile;
  bool get isCheckingDuration => _isCheckingDuration;
  bool get isSaving => _isSaving;
  bool get hasSelectedFile => selectedFilePath != null;
  String? get error => _error;
  bool get hasError => _error != null;

  // Pick audio file from device
  Future<bool> pickAudioFile() async {
    try {
      _logger.info('Starting file picker for audio file selection');
      _setPickingFile(true);
      _clearError();

      // Use file_picker to select audio files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a'],
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        if (file.path != null) {
          selectedFilePath = file.path!;
          _logger.info('File selected: ${file.name}, Path: ${selectedFilePath}');
          
          final fileObj = File(selectedFilePath!);
          if (await fileObj.exists()) {
            final fileSize = await fileObj.length();
            _logger.debug('File exists - Size: ${fileSize} bytes (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
          } else {
            _logger.warning('Selected file does not exist at path');
          }
          
          await _checkAudioDuration();
          
          notifyListeners();
          return true;
        } else {
          _logger.error('Failed to get file path from picker result');
          throw Exception('Failed to get file path');
        }
      } else {
        // User cancelled file selection
        _logger.info('File selection cancelled by user');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.error('Error selecting audio file', e, stackTrace);
      _setError('Error selecting file: ${e.toString()}');
      selectedFilePath = null;
      audioDuration = null;
      return false;
    } finally {
      _setPickingFile(false);
    }
  }

  Future<bool> _checkAudioDuration() async {
    if (selectedFilePath == null) {
      _logger.warning('Cannot check duration: no file selected');
      return false;
    }

    try {
      _logger.info('Checking audio duration for: $selectedFilePath');
      _setCheckingDuration(true);
      
      // Load the audio file to get duration
      await _audioPlayer.setFilePath(selectedFilePath!);
      audioDuration = _audioPlayer.duration;
      
      if (audioDuration != null) {
        _logger.info('Audio duration determined: ${formatDuration(audioDuration)} (${audioDuration!.inSeconds}s)');
        
        if (audioDuration!.inMinutes >= 2) {
          _logger.warning('Audio duration exceeds 2 minutes limit');
        }
      } else {
        _logger.warning('Could not determine audio duration');
      }
      
      return true;
    } catch (e, stackTrace) {
      _logger.error('Error checking audio duration', e, stackTrace);
      _setError('Error checking audio duration: ${e.toString()}');
      return false;
    } finally {
      _setCheckingDuration(false);
    }
  }

  // Save the uploaded audio as an analysis
  Future<AudioAnalysis?> saveAudioAnalysis({bool clipAudio = false}) async {
    if (selectedFilePath == null) {
      _logger.error('Cannot save: no audio file selected');
      _setError('No audio file selected');
      return null;
    }

    if (title.isEmpty) {
      _logger.warning('Cannot save: title is empty');
      _setError('Title is required');
      return null;
    }

    try {
      _logger.info('Saving audio analysis - Title: "$title", ClipAudio: $clipAudio, Duration: ${formatDuration(audioDuration)}');
      _setSaving(true);
      _clearError();

      final analysis = await _audioAnalysisRepository.createAnalysis(
        title: title,
        description: description,
        recordingPath: selectedFilePath!,
      );

      _logger.info('Audio analysis created successfully - ID: ${analysis.id}, Path: ${analysis.recordingPath}');

      // Reset state after successful save
      _resetState();
      
      return analysis;
    } catch (e, stackTrace) {
      _logger.error('Error saving audio analysis', e, stackTrace);
      _setError('Error saving audio analysis: ${e.toString()}');
      return null;
    } finally {
      _setSaving(false);
    }
  }

  void _resetState() {
    _logger.debug('Resetting UploadAudioViewModel state');
    selectedFilePath = null;
    audioDuration = null;
    title = '';
    description = null;
    _error = null;
    notifyListeners();
  }

  void _setPickingFile(bool picking) {
    _logger.debug('Setting picking file state to: $picking');
    _isPickingFile = picking;
    notifyListeners();
  }

  void _setCheckingDuration(bool checking) {
    _logger.debug('Setting checking duration state to: $checking');
    _isCheckingDuration = checking;
    notifyListeners();
  }

  void _setSaving(bool saving) {
    _logger.debug('Setting saving state to: $saving');
    _isSaving = saving;
    notifyListeners();
  }

  void _setError(String error) {
    _logger.warning('Setting error state: $error');
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    if (_error != null) {
      _logger.debug('Clearing error state');
    }
    _error = null;
  }

  String formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _logger.info('Disposing UploadAudioViewModel - Selected file: ${selectedFilePath != null}');
    FilePicker.platform.clearTemporaryFiles();
    _audioPlayer.dispose();
    super.dispose();
  }
}