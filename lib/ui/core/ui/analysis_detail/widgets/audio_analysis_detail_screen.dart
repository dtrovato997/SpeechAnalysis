// lib/ui/core/ui/analysis_detail/widgets/audio_analysis_detail_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/ui/core/ui/analysis_detail/view_models/audio_analysis_detail_view_model.dart';
import 'package:provider/provider.dart';

class AudioAnalysisDetailScreen extends StatefulWidget {
  final int analysisId;

  const AudioAnalysisDetailScreen({Key? key, required this.analysisId})
    : super(key: key);

  @override
  State<StatefulWidget> createState() => _AudioAnalysisDetailScreenState();
}

class _AudioAnalysisDetailScreenState extends State<AudioAnalysisDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AudioAnalysisDetailViewModel(context, analysisId: widget.analysisId),
      child: _AudioAnalysisDetailView(),
    );
  }
}

class _AudioAnalysisDetailView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AudioAnalysisDetailViewModel>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Show loading indicator if loading
    if (viewModel.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Analysis Detail'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: colorScheme.primary,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Information Card
              _buildInformationCard(context, colorScheme, textTheme, viewModel),

              const SizedBox(height: 16),

              // Recording Card
              _buildRecordingCard(context, colorScheme, textTheme, viewModel),

              const SizedBox(height: 16),

              // Results Cards - Horizontally Stacked with fixed equal size
              _buildResultsCardsFixed(context, colorScheme, textTheme, viewModel),

              const SizedBox(height: 16),

              // Analysis Breakdown - Detailed
              _buildAnalysisBreakdownCard(context, colorScheme, textTheme, viewModel),
              
              // Show error if any
              if (viewModel.error != null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    viewModel.error!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInformationCard(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    AudioAnalysisDetailViewModel viewModel,
  ) {
    final analysis = viewModel.analysisDetails;

    return Card(
      elevation: 2,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              viewModel.formatDate(analysis.date),
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(analysis.title, style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(analysis.description, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingCard(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    AudioAnalysisDetailViewModel viewModel,
  ) {
    final analysis = viewModel.analysisDetails;

    return Card(
      elevation: 2,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audio recording',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Play Button
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      viewModel.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: colorScheme.onPrimary,
                    ),
                    onPressed: viewModel.togglePlayback,
                  ),
                ),
                const SizedBox(width: 12),
                // Progress and time indicators
                Expanded(
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                        ),
                        child: Slider(
                          value: viewModel.currentPosition.inMilliseconds.toDouble(),
                          min: 0,
                          max: analysis.totalDuration.inMilliseconds.toDouble(),
                          activeColor: colorScheme.primary,
                          inactiveColor: colorScheme.surfaceVariant,
                          onChanged: (value) {
                            viewModel.seekTo(
                              Duration(milliseconds: value.toInt()),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              viewModel.formatDuration(
                                viewModel.currentPosition,
                              ),
                              style: textTheme.bodySmall,
                            ),
                            Text(
                              viewModel.formatDuration(analysis.totalDuration),
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCardsFixed(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    AudioAnalysisDetailViewModel viewModel,
  ) {
    final analysis = viewModel.analysisDetails;
    
    // Get the most likely age/gender and nationality
    final ageGenderEntry = analysis.ageGenderPredictions.entries
        .reduce((a, b) => a.value > b.value ? a : b);
    final nationalityEntry = analysis.nationalityPredictions.entries
        .reduce((a, b) => a.value > b.value ? a : b);
        
    // Get result text values
    final ageGenderLabel = AudioAnalysisDetailViewModel.ageGenderLabels[ageGenderEntry.key] ?? ageGenderEntry.key;
    final nationalityLabel = AudioAnalysisDetailViewModel.nationalityLabels[nationalityEntry.key] ?? nationalityEntry.key;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analysis results',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Use an IntrinsicHeight widget to ensure both cards have the same height
        IntrinsicHeight(
          child: Row(
            children: [
              // Age/Gender Card - Fixed width
              Expanded(
                child: _buildFixedResultCard(
                  context: context,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  title: 'Età',
                  confidence: ageGenderEntry.value,
                  result: ageGenderLabel,
                  icon: _getAgeGenderIcon(ageGenderEntry.key),
                ),
              ),
              const SizedBox(width: 12),
              // Nationality Card - Fixed width
              Expanded(
                child: _buildFixedResultCard(
                  context: context,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  title: 'Nazionalità',
                  confidence: nationalityEntry.value,
                  result: nationalityLabel,
                  icon: _getNationalityIcon(nationalityEntry.key),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFixedResultCard({
    required BuildContext context,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required String title,
    required double confidence,
    required String result,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.max, // Fill available height
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
                const Spacer(),
                // Thumbs up/down icons
                Row(
                  children: [
                    Icon(
                      Icons.thumb_up_outlined,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.thumb_down_outlined,
                      size: 16,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ],
                ),
              ],
            ),
            // Add spacer to push content to the top
            const Spacer(flex: 1),
            // Result content
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Confidenza: ${confidence.toInt()}%',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            // Add spacer to push content to the top and ensure equal height
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisBreakdownCard(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    AudioAnalysisDetailViewModel viewModel,
  ) {
    final analysis = viewModel.analysisDetails;

    return Card(
      elevation: 2,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analysis breakdown',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Age and Gender Predictions Card
            _buildPredictionSection(
              context: context,
              colorScheme: colorScheme,
              textTheme: textTheme,
              title: 'Age and Gender',
              predictions: analysis.ageGenderPredictions,
              tooltips: AudioAnalysisDetailViewModel.ageGenderLabels,
            ),

            const SizedBox(height: 24),

            // Nationality Predictions Card
            _buildPredictionSection(
              context: context,
              colorScheme: colorScheme,
              textTheme: textTheme,
              title: 'Nationality',
              predictions: analysis.nationalityPredictions,
              tooltips: AudioAnalysisDetailViewModel.nationalityLabels,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionSection({
    required BuildContext context,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required String title,
    required Map<String, double> predictions,
    required Map<String, String> tooltips,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Display prediction values
        Row(
          children: predictions.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Tooltip(
                message: tooltips[entry.key] ?? entry.key,
                child: Text(
                  '${entry.key} (${entry.value.toInt()}%)',
                  style: textTheme.bodyMedium,
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 8),

        // Progress bars for predictions
        Stack(
          children: [
            // Background bar
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            // Stacked prediction bars
            Row(
              children: _buildPredictionBars(context, predictions, colorScheme),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildPredictionBars(
    BuildContext context,
    Map<String, double> predictions,
    ColorScheme colorScheme,
  ) {
    double total = predictions.values.fold(0, (sum, value) => sum + value);

    List<Widget> bars = [];
    double runningWidth = 0;

    predictions.forEach((key, value) {
      double percentage = value / total;

      bars.add(
        Container(
          height: 8,
          width: (MediaQuery.of(context).size.width - 64) * percentage, // Full width minus padding
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.5 + (0.5 * (1 - runningWidth))), // Gradient effect
            borderRadius: BorderRadius.horizontal(
              left: runningWidth == 0 ? const Radius.circular(4) : Radius.zero,
              right: runningWidth + percentage >= 0.99 ? const Radius.circular(4) : Radius.zero,
            ),
          ),
        ),
      );

      runningWidth += percentage;
    });

    return bars;
  }

  IconData _getAgeGenderIcon(String key) {
    if (key.contains('F')) {
      return Icons.female;
    } else if (key.contains('M')) {
      return Icons.male;
    } else if (key.contains('C')) {
      return Icons.child_care;
    }
    return Icons.person;
  }

  IconData _getNationalityIcon(String key) {
    switch (key) {
      case 'IT':
        return Icons.flag;
      case 'FR':
        return Icons.flag;
      case 'EN':
        return Icons.flag;
      default:
        return Icons.public;
    }
  }
}