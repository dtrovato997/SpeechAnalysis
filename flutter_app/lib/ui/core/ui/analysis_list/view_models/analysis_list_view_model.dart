// lib/ui/core/ui/analysis_list/view_models/analysis_list_view_model.dart
import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/data/repositories/audio_analysis_repository.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis/audio_analysis.dart';
import 'package:mobile_speech_recognition/utils/analysis_format_utils.dart';
import 'package:mobile_speech_recognition/services/logger_service.dart';
import 'package:provider/provider.dart';

class AnalysisListViewModel extends ChangeNotifier {
  final _logger = LoggerService();
  final AudioAnalysisRepository _audioAnalysisRepository;
  
  // All loaded analyses
  List<AudioAnalysis> _analyses = [];
  
  // Filtered analyses (based on search)
  List<AudioAnalysis> _filteredAnalyses = [];
  
  // Search query
  String _searchQuery = '';
  
  // Loading state
  bool _isLoading = false;
  
  // Error state
  String? _error;

  // Getters
  List<AudioAnalysis> get analyses => _analyses;
  List<AudioAnalysis> get filteredAnalyses => _filteredAnalyses;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isEmpty => _analyses.isEmpty;
  
  // Constructor
  AnalysisListViewModel(BuildContext context)
      : _audioAnalysisRepository = Provider.of<AudioAnalysisRepository>(context, listen: false) {
    _logger.info('AnalysisListViewModel initialized');
    
    // Register as a listener to the repository
    _audioAnalysisRepository.addListener(_onRepositoryChanged);
    
    // Load initial data
    loadAnalyses();
  }
  
  // Called when the repository data changes
  void _onRepositoryChanged() {
    _logger.debug('Repository changed notification received, reloading analyses');
    // Reload items when repository data changes
    loadAnalyses();
  }
  
  // Load all analyses
  Future<void> loadAnalyses() async {
    _logger.info('Loading all analyses from repository');
    _setLoading(true);
    
    try {
      // Fetch all analyses from the repository
      final analyses = await _audioAnalysisRepository.getAllAudioAnalyses();
      
      _logger.info('Loaded ${analyses.length} analyses from repository');
      
      // Sort by creation date (newest first)
      analyses.sort((a, b) => b.creationDate.compareTo(a.creationDate));
      
      _analyses = analyses;
      _applyFilter(); // Apply current filter
      _error = null;
      
      _logger.debug('Analyses sorted and filtered, ${_filteredAnalyses.length} analyses after filter');
    } catch (e, stackTrace) {
      _error = "Failed to load analyses: ${e.toString()}";
      _logger.error('Failed to load analyses', e, stackTrace);
      
      // Fallback to empty list
      _analyses = [];
      _filteredAnalyses = [];
    } finally {
      _setLoading(false);
    }
  }
  
  // Filter analyses based on search query
  void filterAnalyses(String query) {
    _logger.debug('Filtering analyses with query: "$query"');
    _searchQuery = query.trim();
    _applyFilter();
  }
  
  // Apply filter to analyses
  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      // No filter, show all
      _filteredAnalyses = List.from(_analyses);
      _logger.debug('No filter applied, showing all ${_filteredAnalyses.length} analyses');
    } else {
      // Filter by title, description, tags, age, gender, nationality, and emotion
      _filteredAnalyses = _analyses.where((analysis) {
        final query = _searchQuery.toLowerCase();
        
        // Check title
        final title = analysis.title.toLowerCase();
        final matchesTitle = title.contains(query);
        
        // Check description
        final description = analysis.description?.toLowerCase() ?? '';
        final matchesDescription = description.contains(query);
        
        
        // Check age
        final ageText = AnalysisFormatUtils.parseAgeResult(analysis.ageResult).toLowerCase();
        final matchesAge = ageText.contains(query);
        
        // Check gender
        final genderText = AnalysisFormatUtils.parseGenderResult(analysis.genderResult).toLowerCase();
        final matchesGender = genderText.contains(query);
        
        // Check nationality
        final nationalityText = AnalysisFormatUtils.parseNationalityResult(analysis.nationalityResult).toLowerCase();
        final matchesNationality = nationalityText.contains(query);
        
        // Check emotion
        final emotionText = AnalysisFormatUtils.parseEmotionResult(analysis.emotionResult).toLowerCase();
        final matchesEmotion = emotionText.contains(query);
        
        return matchesTitle || matchesDescription || 
               matchesAge || matchesGender || matchesNationality || matchesEmotion;
      }).toList();
      
      _logger.info('Filter applied: "${_searchQuery}" - Found ${_filteredAnalyses.length} matching analyses out of ${_analyses.length} total');
    }
      
    notifyListeners();
  }

  Future<void> dismissAudioAnalysis(int? id) async {
    if (id == null) {
      _logger.warning('Attempted to dismiss analysis with null ID');
      return;
    }
    
    _logger.info('Dismissing analysis with ID: $id');
    
    try {
      await _audioAnalysisRepository.deleteAudioAnalysis(id, doNotify: true);
      _logger.info('Analysis dismissed successfully: $id');
    } catch (e, stackTrace) {
      _logger.error('Failed to dismiss analysis: $id', e, stackTrace);
      rethrow;
    }
  }
  
  // Update loading state
  void _setLoading(bool loading) {
    _logger.debug('Setting loading state to: $loading');
    _isLoading = loading;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _logger.info('Disposing AnalysisListViewModel');
    // Important: Remove the listener when the ViewModel is disposed
    _audioAnalysisRepository.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}