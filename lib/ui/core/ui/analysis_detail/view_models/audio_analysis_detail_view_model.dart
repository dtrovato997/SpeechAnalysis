// lib/ui/core/ui/analysis_detail/view_models/audio_analysis_detail_view_model.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/data/repositories/audio_analysis_repository.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis/audio_analysis.dart';
import 'package:provider/provider.dart';

class AudioAnalysisDetails {
  final String title;
  final String description;
  final DateTime date;
  final Duration totalDuration;
  final Map<String, double> ageGenderPredictions;
  final Map<String, double> nationalityPredictions;
  
  AudioAnalysisDetails({
    required this.title,
    required this.description,
    required this.date,
    required this.totalDuration,
    required this.ageGenderPredictions,
    required this.nationalityPredictions,
  });
  
  // Factory method to create AudioAnalysisDetails from an AudioAnalysis model
  factory AudioAnalysisDetails.fromAudioAnalysis(AudioAnalysis analysis) {
    // Extract age/gender predictions
    Map<String, double> ageGenderPredictions = {};
    if (analysis.ageResult != null) {
      // Parse age/gender result string into a map
      // This assumes the format is something like "YF:85,YM:10,C:5"
      try {
        final pairs = analysis.ageResult!.split(',');
        for (final pair in pairs) {
          final parts = pair.split(':');
          if (parts.length == 2) {
            ageGenderPredictions[parts[0].trim()] = double.tryParse(parts[1].trim()) ?? 0.0;
          }
        }
      } catch (e) {
        // Fallback if format is different
        ageGenderPredictions = {'Unknown': 100.0};
        print('Error parsing age result: $e');
      }
    } else {
      // Default values if no predictions are available
      ageGenderPredictions = {'YF': 85.0, 'YM': 10.0, 'C': 5.0};
    }
    
    // Extract nationality predictions
    Map<String, double> nationalityPredictions = {};
    if (analysis.nationalityResult != null) {
      // Parse nationality result string into a map
      // This assumes the format is something like "IT:80,FR:12,EN:8"
      try {
        final pairs = analysis.nationalityResult!.split(',');
        for (final pair in pairs) {
          final parts = pair.split(':');
          if (parts.length == 2) {
            nationalityPredictions[parts[0].trim()] = double.tryParse(parts[1].trim()) ?? 0.0;
          }
        }
      } catch (e) {
        // Fallback if format is different
        nationalityPredictions = {'Unknown': 100.0};
        print('Error parsing nationality result: $e');
      }
    } else {
      // Default values if no predictions are available
      nationalityPredictions = {'IT': 80.0, 'FR': 12.0, 'EN': 8.0};
    }
    
    // Calculate duration based on creation and completion dates
    Duration totalDuration = const Duration(minutes: 2); // Default fallback
    if (analysis.completionDate != null && analysis.creationDate != null) {
      totalDuration = analysis.completionDate!.difference(analysis.creationDate);
    }
    
    return AudioAnalysisDetails(
      title: analysis.title,
      description: analysis.description ?? 'No description',
      date: analysis.creationDate,
      totalDuration: totalDuration,
      ageGenderPredictions: ageGenderPredictions,
      nationalityPredictions: nationalityPredictions,
    );
  }
  
  // Factory method to create a sample analysis for testing
  factory AudioAnalysisDetails.sample() {
    return AudioAnalysisDetails(
      title: 'Presentazione progetto',
      description: 'Registrazione della mia presentazione per il progetto finale. Ho analizzato la mia voce per valutare la chiarezza.',
      date: DateTime(2025, 4, 22, 15, 30),
      totalDuration: const Duration(minutes: 2, seconds: 5),
      ageGenderPredictions: {
        'YF': 85, // Young Female
        'YM': 10, // Young Male
        'C': 5,   // Child
      },
      nationalityPredictions: {
        'IT': 80, // Italian
        'FR': 12, // French
        'EN': 8,  // English
      },
    );
  }
}

class AudioAnalysisDetailViewModel with ChangeNotifier {
  // Constants for prediction categories
  static const Map<String, String> ageGenderLabels = {
    'YF': 'Young Female',
    'YM': 'Young Male',
    'F': 'Female',
    'M': 'Male',
    'C': 'Child',
    'Unknown': 'Unknown',
  };
  
  static const Map<String, String> nationalityLabels = {
    'IT': 'Italian',
    'FR': 'French',
    'EN': 'English',
    'ES': 'Spanish',
    'DE': 'German',
    'Unknown': 'Unknown',
  };
  
  // Repository
  final AudioAnalysisRepository _audioAnalysisRepository;
  
  // Analysis data
  AudioAnalysisDetails? _analysisDetails;
  AudioAnalysisDetails get analysisDetails => _analysisDetails ?? AudioAnalysisDetails.sample();
  
  // Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  // Error state
  String? _error;
  String? get error => _error;
  bool get hasError => _error != null;
  
  // Audio playback state
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;
  
  Duration _currentPosition = Duration.zero;
  Duration get currentPosition => _currentPosition;
  
  Timer? _playbackTimer;
  
  // Analysis ID if loading from a backend
  final int? _analysisId;
  
  // Constructor
  AudioAnalysisDetailViewModel(BuildContext context, {int? analysisId})
      : _audioAnalysisRepository = Provider.of<AudioAnalysisRepository>(context, listen: false),
        _analysisId = analysisId {
    // Listen to repository changes
    _audioAnalysisRepository.addListener(_onRepositoryChanged);
    
    // Load the analysis
    _loadAnalysis();
  }
  
  // Called when repository data changes
  void _onRepositoryChanged() {
    // Only reload if we have an analysis ID and it might have been updated
    if (_analysisId != null) {
      _loadAnalysis();
    }
  }
  
  // Load analysis data from repository
  Future<void> _loadAnalysis() async {
    if (_analysisId == null) {
      // If no ID provided, use sample data
      _analysisDetails = AudioAnalysisDetails.sample();
      notifyListeners();
      return;
    }
    
    _setLoading(true);
    
    try {
      // Get the analysis from the repository
      final analysis = await _audioAnalysisRepository.getAnalysisById(_analysisId!);
      
      if (analysis != null) {
        // Convert to AudioAnalysisDetails
        _analysisDetails = AudioAnalysisDetails.fromAudioAnalysis(analysis);
        _error = null;
      } else {
        // Analysis not found, use sample data
        _analysisDetails = AudioAnalysisDetails.sample();
        _error = "Analysis not found";
      }
    } catch (e) {
      // Error occurred, use sample data
      _analysisDetails = AudioAnalysisDetails.sample();
      _error = "Error loading analysis: ${e.toString()}";
      print("Error loading analysis: $e");
    } finally {
      _setLoading(false);
    }
  }
  
  // Update loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  // Audio playback controls
  void togglePlayback() {
    _isPlaying = !_isPlaying;
    
    if (_isPlaying) {
      // Start a timer to simulate audio playback progress
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (_currentPosition < analysisDetails.totalDuration) {
          _currentPosition += const Duration(milliseconds: 100);
          notifyListeners();
        } else {
          stopPlayback();
        }
      });
    } else {
      _playbackTimer?.cancel();
    }
    
    notifyListeners();
  }
  
  void stopPlayback() {
    _isPlaying = false;
    _playbackTimer?.cancel();
    notifyListeners();
  }
  
  void seekTo(Duration position) {
    if (position <= analysisDetails.totalDuration) {
      _currentPosition = position;
      notifyListeners();
    }
  }

  // Format utilities
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
  
  String formatDate(DateTime date) {
    return '${date.day} ${_getMonthName(date.month)} ${date.year}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  String _getMonthName(int month) {
    const months = ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];
    return months[month - 1];
  }
  
  @override
  void dispose() {
    // Remove repository listener
    _audioAnalysisRepository.removeListener(_onRepositoryChanged);
    
    // Cancel playback timer
    _playbackTimer?.cancel();
    
    super.dispose();
  }
}