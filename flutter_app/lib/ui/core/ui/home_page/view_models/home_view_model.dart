// lib/ui/core/ui/home_page/view_models/home_view_model.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/data/repositories/audio_analysis_repository.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis/audio_analysis.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis/audio_analysis_home_summary.dart';
import 'package:mobile_speech_recognition/services/logger_service.dart';
import 'package:provider/provider.dart';

/// ViewModel for managing carousel data
class HomeViewModel extends ChangeNotifier {
  final _logger = LoggerService();
  final AudioAnalysisRepository _audioAnalysisRepository;
  List<AudioAnalysis> _items = [];
  bool _isLoading = false;
  String? _error;

  // Constructor
  HomeViewModel(BuildContext context)
      : _audioAnalysisRepository = Provider.of<AudioAnalysisRepository>(context, listen: false) {
    _logger.info('HomeViewModel initialized');
    
    // Register as a listener to the repository
    _audioAnalysisRepository.addListener(_onRepositoryChanged);
    
    // Load initial data
    loadItems();
  }

  // Getters
  List<AudioAnalysis> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isEmpty => _items.isEmpty;

  // Called when the repository data changes
  void _onRepositoryChanged() {
    _logger.debug('Repository changed notification received, reloading recent analyses');
    // Reload items when repository data changes
    loadItems();
  }

  // Load recent analyses
  Future<void> loadItems() async {
    _logger.info('Loading recent analyses (limit: 5)');
    _setLoading(true);
    
    try {
      // Fetch actual analyses from the repository
      _items = await _audioAnalysisRepository.getRecentAnalyses(limit: 5);
      
      _logger.info('Loaded ${_items.length} recent analyses successfully');
      _error = null;
    } catch (e, stackTrace) {
      _error = "Failed to load analyses: ${e.toString()}";
      _logger.error('Failed to load recent analyses', e, stackTrace);
      
      // Fallback to empty list
      _items = [];
    } finally {
      _setLoading(false);
    }
  }

  // Add a new item
  void addItem(AudioAnalysis item) {
    _logger.debug('Adding item to home view: ${item.id} - "${item.title}"');
    _items.add(item);
    notifyListeners();
  }

  // Remove an item by id
  void removeItem(String id) {
    _logger.debug('Removing item from home view: $id');
    final initialCount = _items.length;
    _items.removeWhere((item) => item.id == id);
    final removedCount = initialCount - _items.length;
    
    if (removedCount > 0) {
      _logger.info('Removed $removedCount item(s) with id: $id');
    } else {
      _logger.warning('Attempted to remove item with id $id but it was not found');
    }
    
    notifyListeners();
  }

  // Clear all items
  void clearItems() {
    _logger.info('Clearing all items from home view (${_items.length} items)');
    _items.clear();
    notifyListeners();
  }

  // Update loading state
  void _setLoading(bool loading) {
    _logger.debug('Setting home view loading state to: $loading');
    _isLoading = loading;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _logger.info('Disposing HomeViewModel');
    // Important: Remove the listener when the ViewModel is disposed
    _audioAnalysisRepository.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}