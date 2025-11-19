import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis/audio_analysis_home_summary.dart';
import 'package:mobile_speech_recognition/ui/core/analysis_card.dart';
import 'package:mobile_speech_recognition/ui/core/ui/home_page/view_models/home_view_model.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:mobile_speech_recognition/utils/date_time_utils.dart';
import 'package:mobile_speech_recognition/ui/core/ui/analysis_detail/widgets/audio_analysis_detail_screen.dart';
import 'package:mobile_speech_recognition/services/logger_service.dart';

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
  final _logger = LoggerService();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _logger.debug('RecentAnalysisViewPager initialized');
  }
  
  @override
  void dispose() {
    _logger.debug('RecentAnalysisViewPager disposing');
    super.dispose();
  }
  
  @override
  void didUpdateWidget(RecentAnalysisViewPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      _logger.debug('RecentAnalysisViewPager viewModel updated');
    }
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
          _logger.debug('RecentAnalysisViewPager showing loading state');
          return Center(
            child: CircularProgressIndicator(
              color: colorScheme.primary,
            ),
          );
        }
        
        if (widget.viewModel.hasError) {
          _logger.warning('RecentAnalysisViewPager showing error state: ${widget.viewModel.error}');
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
          _logger.debug('RecentAnalysisViewPager showing empty state');
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
        _logger.debug('RecentAnalysisViewPager displaying ${items.length} analyses');
      
        MediaQueryData mediaQuery = MediaQuery.of(context);
        double screenWidth = mediaQuery.size.width;
        final viewportFraction = items.length == 1 ? 1.0 : (screenWidth > 600 ? 0.4 : 0.9);
        
        _logger.debug('RecentAnalysisViewPager viewport fraction: $viewportFraction (screen width: $screenWidth)');

        // Return the carousel widget
        return ExpandableCarousel.builder(
          itemCount: items.length,
          options: ExpandableCarouselOptions(
            showIndicator: false,
            pageSnapping: true,
            padEnds: false,
            physics: const ClampingScrollPhysics(),
            viewportFraction: viewportFraction,
          ),
          itemBuilder:(context, index, viewPageIndex) {
            final analysis = items[index];
            return Padding(
              padding: const EdgeInsets.only(
                right: 16.0, 
                top: 8.0, 
                bottom: 24.0,
              ),
              child: AnalysisCard(
                analysis: analysis,
                onTap: () {
                  _logger.debug('Recent analysis card tapped in carousel: ${analysis.id} - "${analysis.title}"');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AudioAnalysisDetailScreen(
                        analysisId: analysis.id!,
                      ),
                    ),
                  );
                },
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
        return Colors.amber.shade600;
      case 'Completed':
        return Colors.green.shade500;
      case 'Failed':
        return Colors.red.shade400;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }
}