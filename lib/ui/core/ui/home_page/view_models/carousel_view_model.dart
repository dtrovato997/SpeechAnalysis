import 'package:flutter/foundation.dart';
import 'package:mobile_speech_recognition/data/repositories/audio_analysis_repository.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis.dart';

/// Model class for carousel items
class CarouselItem {
  final String title;
  final String? status;
  final String? imageUrl;
  final DateTime? date;
  final String? id;

  CarouselItem({
    required this.title,
    this.status,
    this.imageUrl,
    this.date,
    this.id,
  });
  
  // Factory method to create a CarouselItem from an AudioAnalysis
  factory CarouselItem.fromAudioAnalysis(AudioAnalysis analysis) {
    // Calculate duration string if needed (this would require additional info)
    String subtitle = '';
    
    // You could determine the subtitle based on the analysis state
    if (analysis.completionDate != null) {
      subtitle = 'Completed';
    } else if (analysis.sendStatus == 1) { // Assuming 1 is TO_SEND based on spec
      subtitle = 'Pending';
    } else if (analysis.sendStatus == 4) { // Assuming 4 is FAILED based on spec
      subtitle = 'Failed';
    }
    
    return CarouselItem(
      id: analysis.id?.toString(),
      title: analysis.title,
      status: subtitle,
      date: analysis.creationDate,
    );
  }
}

/// ViewModel for managing carousel data
class CarouselViewModel extends ChangeNotifier {
  List<CarouselItem> _items = [];
  bool _isLoading = false;
  String? _error;
  final AudioAnalysisRepository _audioAnalysisRepository = AudioAnalysisRepository();

  // Getters
  List<CarouselItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isEmpty => _items.isEmpty;

 // Load recent analyses
  Future<void> loadItems() async {
    _setLoading(true);
    
    try {
      // Fetch actual analyses from the repository
      final analyses = await _audioAnalysisRepository.getRecentAnalyses(limit: 5);
      
      // Convert analyses to carousel items
      _items = analyses.map((analysis) => CarouselItem.fromAudioAnalysis(analysis)).toList();
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
  void addItem(CarouselItem item) {
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
}