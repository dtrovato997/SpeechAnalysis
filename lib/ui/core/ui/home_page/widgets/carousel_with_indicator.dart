import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/ui/core/ui/home_page/view_models/carousel_view_model.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';

class CarouselWithIndicator extends StatefulWidget {
  final double viewportFraction;
  final double horizontalPadding;
  final CarouselViewModel? viewModel; // Optional: can be provided from outside
  final Function(CarouselItem)? onItemTap;
  
  const CarouselWithIndicator({
    Key? key, 
    this.viewportFraction = 0.9,
    this.horizontalPadding = 16.0,
    this.viewModel,
    this.onItemTap,
  }) : super(key: key);

  @override
  State<CarouselWithIndicator> createState() => _CarouselWithIndicatorState();
}

class _CarouselWithIndicatorState extends State<CarouselWithIndicator> {
  late CarouselViewModel _viewModel;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Use provided ViewModel or create a local one
    _viewModel = widget.viewModel ?? CarouselViewModel();
    
    // If we're using a local ViewModel, load the data
    if (widget.viewModel == null) {
      _viewModel.loadItems();
    }
  }
  
  @override
  void dispose() {
    // Only dispose the ViewModel if we created it locally
    if (widget.viewModel == null) {
      _viewModel.dispose();
    }
    super.dispose();
  }
  
  @override
  void didUpdateWidget(CarouselWithIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If the ViewModel reference changes, update our local reference
    if (widget.viewModel != null && widget.viewModel != oldWidget.viewModel) {
      // Clean up the old ViewModel if we created it
      if (oldWidget.viewModel == null) {
        _viewModel.dispose();
      }
      
      _viewModel = widget.viewModel!;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get theme colors
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    // Use AnimatedBuilder to listen to ViewModel changes
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        if (_viewModel.isLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: colorScheme.primary,
            ),
          );
        }
        
        if (_viewModel.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error: ${_viewModel.error}',
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          );
        }
        
        // Handle empty state
        if (_viewModel.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
              child: Card(
                color: colorScheme.surfaceVariant,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No recent analyses available',
                    style: textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        
        // If items count changed, we need to recreate the PageController
        // with the appropriate viewportFraction
        final items = _viewModel.items;
      
        // Return the carousel widget
        return ExpandableCarousel.builder(
          itemCount: items.length,
          options: ExpandableCarouselOptions(
            showIndicator: false,
            pageSnapping: true,
            padEnds: false,
            physics: const ClampingScrollPhysics(),
            viewportFraction: items.length == 1 ? 1.0 : widget.viewportFraction,
          ),
          itemBuilder:(context, index, viewPageIndex) {
            final item = items[index];                  
            return Padding(
              padding: const EdgeInsets.only(
                right: 16.0, 
                top: 8.0, 
                bottom: 24.0,
              ),
              child: GestureDetector(
                onTap: () {
                  if (widget.onItemTap != null) {
                    widget.onItemTap!(item);
                  }
                },
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (widget.onItemTap != null) {
                        widget.onItemTap!(item);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.title,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (item.subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                item.subtitle!,
                                style: textTheme.bodyMedium,
                              ),
                            ),
                          if (item.date != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _formatDate(item.date!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}