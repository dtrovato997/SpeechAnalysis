// lib/ui/core/ui/upload_audio/view_models/upload_audio_view_model.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/data/repositories/audio_analysis_repository.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis/audio_analysis.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';

class UploadAudioViewModel extends ChangeNotifier {
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
    : _audioAnalysisRepository = Provider.of<AudioAnalysisRepository>(context, listen: false);

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
          
          await _checkAudioDuration();
          
          notifyListeners();
          return true;
        } else {
          throw Exception('Failed to get file path');
        }
      } else {
        // User cancelled file selection
        return false;
      }
    } catch (e) {
      _setError('Error selecting file: ${e.toString()}');
      selectedFilePath = null;
      audioDuration = null;
      return false;
    } finally {
      _setPickingFile(false);
    }
  }

  Future<bool> _checkAudioDuration() async {
    if (selectedFilePath == null) return false;

    try {
      _setCheckingDuration(true);
      
      // Load the audio file to get duration
      await _audioPlayer.setFilePath(selectedFilePath!);
      audioDuration = _audioPlayer.duration;
      
      return true;
    } catch (e) {
      _setError('Error checking audio duration: ${e.toString()}');
      return false;
    } finally {
      _setCheckingDuration(false);
    }
  }

  // Save the uploaded audio as an analysis
  Future<AudioAnalysis?> saveAudioAnalysis({bool clipAudio = false}) async {
    if (selectedFilePath == null) {
      _setError('No audio file selected');
      return null;
    }

    if (title.isEmpty) {
      _setError('Title is required');
      return null;
    }

    try {
      _setSaving(true);
      _clearError();


      final analysis = await _audioAnalysisRepository.createAnalysis(
        title: title,
        description: description,
        recordingPath: selectedFilePath!,
      );

      // Reset state after successful save
      _resetState();
      
      return analysis;
    } catch (e) {
      _setError('Error saving audio analysis: ${e.toString()}');
      return null;
    } finally {
      _setSaving(false);
    }
  }

  void _resetState() {
    selectedFilePath = null;
    audioDuration = null;
    title = '';
    description = null;
    _error = null;
    notifyListeners();
  }

  void _setPickingFile(bool picking) {
    _isPickingFile = picking;
    notifyListeners();
  }

  void _setCheckingDuration(bool checking) {
    _isCheckingDuration = checking;
    notifyListeners();
  }

  void _setSaving(bool saving) {
    _isSaving = saving;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
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
    FilePicker.platform.clearTemporaryFiles();
    _audioPlayer.dispose();
    super.dispose();
  }
}