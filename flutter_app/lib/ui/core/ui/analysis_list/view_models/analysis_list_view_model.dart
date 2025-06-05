// lib/ui/core/ui/analysis_list/view_models/analysis_list_view_model.dart
import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/data/repositories/audio_analysis_repository.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis/audio_analysis.dart';
import 'package:mobile_speech_recognition/utils/analysis_format_utils.dart';
import 'package:provider/provider.dart';

class AnalysisListViewModel extends ChangeNotifier {
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
    // Register as a listener to the repository
    _audioAnalysisRepository.addListener(_onRepositoryChanged);
    
    // Load initial data
    loadAnalyses();
  }
  
  // Called when the repository data changes
  void _onRepositoryChanged() {
    // Reload items when repository data changes
    loadAnalyses();
  }
  
  // Load all analyses
  Future<void> loadAnalyses() async {
    _setLoading(true);
    
    try {
      // Fetch all analyses from the repository
      final analyses = await _audioAnalysisRepository.getAllAudioAnalyses();
      
      // Sort by creation date (newest first)
      analyses.sort((a, b) => b.creationDate.compareTo(a.creationDate));
      
      _analyses = analyses;
      _applyFilter(); // Apply current filter
      _error = null;
    } catch (e) {
      _error = "Failed to load analyses: ${e.toString()}";
      // Fallback to empty list
      _analyses = [];
      _filteredAnalyses = [];
    } finally {
      _setLoading(false);
    }
  }
  
  // Filter analyses based on search query
  void filterAnalyses(String query) {
    _searchQuery = query.trim();
    _applyFilter();
  }
  
  // Apply filter to analyses
  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      // No filter, show all
      _filteredAnalyses = List.from(_analyses);
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
        
        // Check tags
        bool matchesTag = false;
        if (analysis.tags != null) {
          matchesTag = analysis.tags!.any((tag) => 
            tag.name.toLowerCase().contains(query)
          );
        }
        
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
        
        return matchesTitle || matchesDescription || matchesTag || 
               matchesAge || matchesGender || matchesNationality || matchesEmotion;
      }).toList();
    }
      
    notifyListeners();
  }

  Future<void> dismissAudioAnalysis(int? id) async {
     await _audioAnalysisRepository.deleteAudioAnalysis(id!,doNotify: true);
  }
  
  // Update loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  @override
  void dispose() {
    // Important: Remove the listener when the ViewModel is disposed
    _audioAnalysisRepository.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}