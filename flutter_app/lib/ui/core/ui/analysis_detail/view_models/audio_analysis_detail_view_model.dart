// lib/ui/core/ui/analysis_detail/view_models/audio_analysis_detail_view_model.dart
import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/data/repositories/audio_analysis_repository.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis/audio_analysis.dart';
import 'package:provider/provider.dart';

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
  AudioAnalysis? _analysisDetail;
  AudioAnalysis? get analysisDetail => _analysisDetail;

  // Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Error state
  String? _error;
  String? get error => _error;
  bool get hasError => _error != null;

  // Analysis ID
  final int? _analysisId;

  // Like/dislike status
  Map<String, int> _likeStatus = {'AgeAndGender': 0, 'Nationality': 0};

  // Get like status (1 = like, -1 = dislike, 0 = neutral)
  int getLikeStatus(String resultType) {
    return _likeStatus[resultType] ?? 0;
  }

  // Set like status and notify listeners
  void setLikeStatus(String resultType, int status) {
    // If already in this status, toggle back to neutral
    if (_likeStatus[resultType] == status) {
      _likeStatus[resultType] = 0;
    } else {
      _likeStatus[resultType] = status;
    }
    notifyListeners();

    // Here you could also send feedback to your backend
    // e.g., _apiService.sendFeedback(analysisId, resultType, status);
  }

  // Constructor
  AudioAnalysisDetailViewModel(BuildContext context, {int? analysisId})
    : _audioAnalysisRepository = Provider.of<AudioAnalysisRepository>(
        context,
        listen: false,
      ),
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
    _setLoading(true);

    try {
      // Get the analysis from the repository
      final analysis = await _audioAnalysisRepository.getAnalysisById(
        _analysisId!,
      );

      if (analysis != null) {
        _error = null;
        _analysisDetail = analysis;
      } else {
        _error = "Analysis not found";
      }
    } catch (e) {
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

  // Format utilities
  String formatDate(DateTime date) {
    return '${date.day} ${_getMonthName(date.month)} ${date.year}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getMonthName(int month) {
    const months = [
      'Gen',
      'Feb',
      'Mar',
      'Apr',
      'Mag',
      'Giu',
      'Lug',
      'Ago',
      'Set',
      'Ott',
      'Nov',
      'Dic',
    ];
    return months[month - 1];
  }

  @override
  void dispose() {
    // Remove repository listener
    _audioAnalysisRepository.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}