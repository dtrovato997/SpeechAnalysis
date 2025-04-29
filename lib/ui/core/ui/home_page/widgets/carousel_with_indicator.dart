import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/ui/core/ui/home_page/view_models/carousel_view_model.dart';


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
  late PageController _pageController;
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
    
    _initializePageController();
  }
  
  void _initializePageController() {
    // Initialize with default values, will be updated in build method
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 0.9,
    );
  }

  @override
  void dispose() {
    // Only dispose the ViewModel if we created it locally
    if (widget.viewModel == null) {
      _viewModel.dispose();
    }
    _pageController.dispose();
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
    // Use AnimatedBuilder to listen to ViewModel changes
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        if (_viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (_viewModel.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error: ${_viewModel.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        
        // Handle empty state
        if (_viewModel.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
              child: const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No recent analyses available',
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
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
        if (_pageController.viewportFraction != 
            (items.length == 1 ? 1.0 : widget.viewportFraction)) {
          _pageController.dispose();
          _pageController = PageController(
            initialPage: _currentPage < items.length ? _currentPage : 0,
            viewportFraction: items.length == 1 ? 1.0 : widget.viewportFraction,
          );
        }

        return Column(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.only(left: widget.horizontalPadding),
                child: PageView.builder(
                  controller: _pageController,
                  pageSnapping: true,
                  padEnds: false,
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    
                    return Padding(
                      padding: const EdgeInsets.only(
                        right: 16.0, 
                        top: 8.0, 
                        bottom: 8.0,
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
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 18, 
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                                if (item.subtitle != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      item.subtitle!,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                if (item.date != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      _formatDate(item.date!),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (items.length > 1)
              Container(
                margin: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(items.length, (int index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      height: 8.0,
                      width: 8.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? Colors.blue
                            : Colors.grey.withOpacity(0.5),
                      ),
                    );
                  }),
                ),
              ),
          ],
        );
      },
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}