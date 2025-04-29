import 'package:flutter/foundation.dart';

/// Model class for carousel items
class CarouselItem {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final DateTime? date;
  final String? id;

  CarouselItem({
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.date,
    this.id,
  });
}

/// ViewModel for managing carousel data
class CarouselViewModel extends ChangeNotifier {
  List<CarouselItem> _items = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<CarouselItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isEmpty => _items.isEmpty;

  // Load initial data
  Future<void> loadItems() async {
    _setLoading(true);
    
    try {
      // In a real app, you would fetch data from a service or repository
      // For now, we'll simulate a network delay and use mock data
      await Future.delayed(const Duration(milliseconds: 800));
      
      _items = _getMockItems();
      _error = null;
    } catch (e) {
      _error = "Failed to load items: ${e.toString()}";
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

  // Mock data for testing
  List<CarouselItem> _getMockItems() {
    return [
      CarouselItem(
        id: '1',
        title: 'Speech Analysis #1',
        subtitle: 'Duration: 2m 30s',
        date: DateTime.now().subtract(const Duration(days: 1)),
      ),
      CarouselItem(
        id: '2',
        title: 'Speech Analysis #2',
        subtitle: 'Duration: 4m 15s',
        date: DateTime.now().subtract(const Duration(days: 3)),
      ),
      CarouselItem(
        id: '3',
        title: 'Speech Analysis #3',
        subtitle: 'Duration: 1m 45s',
        date: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];
  }
}