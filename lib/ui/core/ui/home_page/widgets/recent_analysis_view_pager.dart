import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis/audio_analysis_home_summary.dart';
import 'package:mobile_speech_recognition/ui/core/ui/home_page/view_models/home_view_model.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:mobile_speech_recognition/utils/date_time_utils.dart';

class RecentAnalysisViewPager extends StatefulWidget {
  final double viewportFraction;
  final double horizontalPadding;
  final HomeViewModel viewModel; // Optional: can be provided from outside
  final Function(AudioAnalysisHomeSummary)? onItemTap;
  
  const RecentAnalysisViewPager({
    Key? key, 
    this.viewportFraction = 0.9,
    this.horizontalPadding = 16.0,
    required this.viewModel,
    this.onItemTap,
  }) : super(key: key);

  @override
  State<RecentAnalysisViewPager> createState() => _RecentAnalysisViewPagerState();
}

class _RecentAnalysisViewPagerState extends State<RecentAnalysisViewPager> {
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  @override
  void didUpdateWidget(RecentAnalysisViewPager oldWidget) {
    super.didUpdateWidget(oldWidget);
   

  }

  @override
  Widget build(BuildContext context) {
    // Get theme colors
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    // Use AnimatedBuilder to listen to ViewModel changes
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        if (widget.viewModel.isLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: colorScheme.primary,
            ),
          );
        }
        
        if (widget.viewModel.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error: ${widget.viewModel.error}',
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          );
        }
        
        // Handle empty state
        if (widget.viewModel.isEmpty) {
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
        final items = widget.viewModel.items;
      
        MediaQueryData mediaQuery = MediaQuery.of(context);
        double screenWidth = mediaQuery.size.width;

        // Return the carousel widget
        return ExpandableCarousel.builder(
          itemCount: items.length,
          options: ExpandableCarouselOptions(
            showIndicator: false,
            pageSnapping: true,
            padEnds: false,
            physics: const ClampingScrollPhysics(),
            viewportFraction: items.length == 1 ? 1.0 : (screenWidth > 600 ? 0.4 : 0.9),
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
                          if (item.status != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                item.status!,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: _getStatusColor(item.status!, colorScheme),
                                ),
                              ),
                            ),
                          if (item.date != null)
                            
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateTimeUtils.getRelativeTimeSpan(item.date!),
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
  
  _getStatusColor(String s, ColorScheme colorScheme) 
  {
    switch (s) {
      case 'Pending':
        return Colors.yellow.shade300;
      case 'Completed':
        return Colors.green.shade300;
      case 'Failed':
        return Colors.red.shade300;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }
  
}