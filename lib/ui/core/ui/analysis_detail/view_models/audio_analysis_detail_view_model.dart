import 'dart:async';
import 'package:flutter/foundation.dart';

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
  };
  
  static const Map<String, String> nationalityLabels = {
    'IT': 'Italian',
    'FR': 'French',
    'EN': 'English',
    'ES': 'Spanish',
    'DE': 'German',
  };
  
  // Analysis data
  AudioAnalysisDetails? _analysisDetails;
  AudioAnalysisDetails get analysisDetails => _analysisDetails ?? AudioAnalysisDetails.sample();
  
  // Audio playback state
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;
  
  Duration _currentPosition = Duration.zero;
  Duration get currentPosition => _currentPosition;
  
  Timer? _playbackTimer;
  
  // Analysis ID if loading from a backend
  String? _analysisId;
  
  AudioAnalysisDetailViewModel({String? analysisId}) {
    _analysisId = analysisId;
    _loadAnalysis();
  }
  
  // Load analysis data (simulated)
  Future<void> _loadAnalysis() async {
    // In a real app, this would fetch data from a repository or API
    // For now, we'll use a sample analysis
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    
    _analysisDetails = AudioAnalysisDetails.sample();
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
    _playbackTimer?.cancel();
    super.dispose();
  }
}