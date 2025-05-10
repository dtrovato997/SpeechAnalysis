// lib/ui/core/ui/home_page/view_models/home_view_model.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/data/repositories/audio_analysis_repository.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis/audio_analysis_home_summary.dart';
import 'package:provider/provider.dart';

/// ViewModel for managing carousel data
class HomeViewModel extends ChangeNotifier {
  final AudioAnalysisRepository _audioAnalysisRepository;
  List<AudioAnalysisHomeSummary> _items = [];
  bool _isLoading = false;
  String? _error;

  // Constructor
  HomeViewModel(BuildContext context)
      : _audioAnalysisRepository = Provider.of<AudioAnalysisRepository>(context, listen: false) {
    // Register as a listener to the repository
    _audioAnalysisRepository.addListener(_onRepositoryChanged);
    
    // Load initial data
    loadItems();
  }

  // Getters
  List<AudioAnalysisHomeSummary> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isEmpty => _items.isEmpty;

  // Called when the repository data changes
  void _onRepositoryChanged() {
    // Reload items when repository data changes
    loadItems();
  }

  // Load recent analyses
  Future<void> loadItems() async {
    _setLoading(true);
    
    try {
      // Fetch actual analyses from the repository
      final analyses = await _audioAnalysisRepository.getRecentAnalyses(limit: 5);
      
      // Convert analyses to carousel items
      _items = analyses.map((analysis) => AudioAnalysisHomeSummary.fromAudioAnalysis(analysis)).toList();
      _error = null;
    } catch (e) {
      _error = "Failed to load analyses: ${e.toString()}";
      // Fallback to empty list
      _items = [];
    } finally {
      _setLoading(false);
    }
  }

  // Add a new item
  void addItem(AudioAnalysisHomeSummary item) {
    _items.add(item);
    notifyListeners();
  }

  // Remove an item by id
  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  // Clear all items
  void clearItems() {
    _items.clear();
    notifyListeners();
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