// lib/ui/core/ui/analysis_detail/view_models/audio_analysis_detail_view_model.dart
import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/data/repositories/audio_analysis_repository.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis/audio_analysis.dart';
import 'package:mobile_speech_recognition/services/logger_service.dart';
import 'package:provider/provider.dart';

class AudioAnalysisDetailViewModel with ChangeNotifier {
  // Logger instance
  final _logger = LoggerService();

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

  // Retry loading state
  bool _isRetrying = false;
  bool get isRetrying => _isRetrying;

  // Delete loading state
  bool _isDeleting = false;
  bool get isDeleting => _isDeleting;

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

  // Constructor
  AudioAnalysisDetailViewModel(BuildContext context, {int? analysisId})
    : _audioAnalysisRepository = Provider.of<AudioAnalysisRepository>(
        context,
        listen: false,
      ),
      _analysisId = analysisId {
    _logger.info('AudioAnalysisDetailViewModel initialized with analysisId: $_analysisId');
    
    // Listen to repository changes
    _audioAnalysisRepository.addListener(_onRepositoryChanged);

    // Load the analysis
    _loadAnalysis();
  }

  // Called when repository data changes
  void _onRepositoryChanged() {
    _logger.debug('Repository changed notification received for analysis: $_analysisId');
    
    // Only reload if we have an analysis ID and it might have been updated
    if (_analysisId != null && !_isDeleting) {
      _logger.debug('Reloading analysis data due to repository change');
      _loadAnalysis();
    }
  }

  // Load analysis data from repository
  Future<void> _loadAnalysis() async {
    _logger.info('Loading analysis with ID: $_analysisId');
    _setLoading(true);

    try {
      // Get the analysis from the repository
      final analysis = await _audioAnalysisRepository.getAnalysisById(
        _analysisId!,
      );

      if (analysis != null) {
        _logger.info('Analysis loaded successfully - ID: ${analysis.id}, Status: ${analysis.sendStatus}');
        _error = null;
        _analysisDetail = analysis;
      } else {
        _error = "Analysis not found";
        _logger.warning('Analysis not found with ID: $_analysisId');
      }
    } catch (e, stackTrace) {
      _error = "Error loading analysis: ${e.toString()}";
      _logger.error('Error loading analysis with ID: $_analysisId', e, stackTrace);
    } finally {
      _setLoading(false);
    }
  }

  // Delete analysis
  Future<void> deleteAnalysis() async {
    if (_analysisId == null) {
      _logger.error('Attempted to delete analysis with null ID');
      throw Exception("No analysis ID available for deletion");
    }

    _logger.info('Deleting analysis with ID: $_analysisId');
    _setDeleting(true);

    try {
      // Delete the analysis from the repository
      await _audioAnalysisRepository.deleteAudioAnalysis(_analysisId!, doNotify: true);
      
      _logger.info('Analysis deleted successfully - ID: $_analysisId');
      
      // Clear the local analysis data
      _analysisDetail = null;
      _error = null;
      
      // Note: We don't notify listeners here as the screen will be popped
      // and the repository will handle notifying other listeners
    } catch (e, stackTrace) {
      _error = "Error deleting analysis: ${e.toString()}";
      _logger.error('Error deleting analysis with ID: $_analysisId', e, stackTrace);
      rethrow; // Re-throw so the UI can handle the error
    } finally {
      _setDeleting(false);
    }
  }

  // Retry failed analysis
  Future<void> retryAnalysis() async {
    if (_analysisId == null || _analysisDetail == null) {
      _logger.warning('Attempted to retry analysis with null ID or detail');
      return;
    }

    // Only allow retry for failed analyses
    if (_analysisDetail!.sendStatus != AudioAnalysisRepository.SEND_STATUS_ERROR) {
      _logger.warning('Attempted to retry analysis with non-error status: ${_analysisDetail!.sendStatus}');
      return;
    }

    _logger.info('Retrying failed analysis with ID: $_analysisId');
    _setRetrying(true);

    try {
      await _audioAnalysisRepository.retryAnalysis(_analysisId!);
      _logger.info('Analysis retry initiated successfully - ID: $_analysisId');
      // The repository will notify listeners, which will trigger _onRepositoryChanged
      // and reload the analysis data
    } catch (e, stackTrace) {
      _logger.error('Error retrying analysis with ID: $_analysisId', e, stackTrace);
      // You could show a snackbar or other error indication here
    } finally {
      _setRetrying(false);
    }
  }

  // Update loading state
  void _setLoading(bool loading) {
    _logger.debug('Setting loading state to: $loading for analysis: $_analysisId');
    _isLoading = loading;
    notifyListeners();
  }

  // Update retry loading state
  void _setRetrying(bool retrying) {
    _logger.debug('Setting retrying state to: $retrying for analysis: $_analysisId');
    _isRetrying = retrying;
    notifyListeners();
  }

  // Update delete loading state
  void _setDeleting(bool deleting) {
    _logger.debug('Setting deleting state to: $deleting for analysis: $_analysisId');
    _isDeleting = deleting;
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
    _logger.info('Disposing AudioAnalysisDetailViewModel for analysis: $_analysisId');
    // Remove repository listener
    _audioAnalysisRepository.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}