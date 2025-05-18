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
  late AudioAnalysisDetailViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = AudioAnalysisDetailViewModel(
      context,
      analysisId: widget.analysisId,
    );
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ChangeNotifierProvider.value(
      value: viewModel,
      child: Consumer<AudioAnalysisDetailViewModel>(
        builder: (context, value, child) {
          if (viewModel.isLoading) {
            return Scaffold(
              appBar: AppBar(
                title: Text(
                  'Analysis Detail',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),

                  textAlign: TextAlign.left,
                ),

                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(
                'Analysis Detail',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),

                textAlign: TextAlign.left,
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Information Card
                    _buildInformationCard(
                      context,
                      colorScheme,
                      textTheme,
                      viewModel,
                    ),

                    const SizedBox(height: 16),

                    // Recording Card
                    _buildRecordingCard(
                      context,
                      colorScheme,
                      textTheme,
                      viewModel,
                    ),

                    const SizedBox(height: 16),

                    // Results Cards - Vertically Stacked
                    _buildResultsCardsFixed(
                      context,
                      colorScheme,
                      textTheme,
                      viewModel,
                    ),

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
        },
      ),
    ); // Show loading indicator if loading
  }

  Widget _buildInformationCard(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    AudioAnalysisDetailViewModel viewModel,
  ) {
    final analysis = viewModel.analysisDetail;

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
              viewModel.formatDate(analysis!.creationDate),
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(analysis.title, style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              analysis.description ?? 'No description available',
              style: textTheme.bodyMedium,
            ),
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
    final analysis = viewModel.analysisDetail;

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
                          value:
                              viewModel.currentPosition.inMilliseconds
                                  .toDouble(),
                          min: 0,
                          max:
                              viewModel.recordingDuration.inMilliseconds
                                  .toDouble(),
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
                              viewModel.formatDuration(
                                viewModel.recordingDuration,
                              ),
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
    final analysis = viewModel.analysisDetail;

    if (analysis?.sendStatus != 1) {
      //Da sostituire con il loading
      return const SizedBox.shrink();
    }
    // Get the most likely age/gender and nationality
    final ageGenderEntry = analysis?.ageAndGenderResult?.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
    final nationalityEntry = analysis?.nationalityResult?.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    if (ageGenderEntry == null || nationalityEntry == null) {
      return const SizedBox.shrink(); // Return an empty widget if data is null
    }

    // Get result text values
    final ageGenderLabel =
        AudioAnalysisDetailViewModel.ageGenderLabels[ageGenderEntry.key] ??
        ageGenderEntry.key;

    // Determine if this is "Giovane donna" or other combinations
    String localizedAgeGenderLabel = ageGenderLabel;
    if (ageGenderEntry.key.contains('YF')) {
      localizedAgeGenderLabel = 'Giovane donna';
    } else if (ageGenderEntry.key.contains('YM')) {
      localizedAgeGenderLabel = 'Giovane uomo';
    } else if (ageGenderEntry.key.contains('F')) {
      localizedAgeGenderLabel = 'Donna';
    } else if (ageGenderEntry.key.contains('M')) {
      localizedAgeGenderLabel = 'Uomo';
    } else if (ageGenderEntry.key.contains('C')) {
      localizedAgeGenderLabel = 'Bambino';
    }

    // Get nationality in Italian
    final italianNationalityLabel =
        nationalityEntry.key == 'IT'
            ? 'Italiano'
            : nationalityEntry.key == 'FR'
            ? 'Francese'
            : nationalityEntry.key == 'EN'
            ? 'Inglese'
            : nationalityEntry.key == 'ES'
            ? 'Spagnolo'
            : nationalityEntry.key == 'DE'
            ? 'Tedesco'
            : 'Sconosciuto';

    return Card(
      elevation: 2,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                'Analysis Result',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Stacked cards
            Divider(),
            Column(
              children: [
                // Age/Gender Card
                _buildResultCard(
                  context: context,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  title: 'Età',
                  confidence: ageGenderEntry.value,
                  result: localizedAgeGenderLabel,
                  icon: _getAgeGenderIcon(ageGenderEntry.key),
                  onLike: () => viewModel.setLikeStatus('AgeAndGender', 1),
                  onDislike: () => viewModel.setLikeStatus('AgeAndGender', -1),
                  isLiked: viewModel.getLikeStatus('AgeAndGender') == 1,
                  isDisliked: viewModel.getLikeStatus('AgeAndGender') == -1,
                ),
                const SizedBox(height: 12),
                // Nationality Card
                _buildResultCard(
                  context: context,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  title: 'Nazionalità',
                  confidence: nationalityEntry.value,
                  result: italianNationalityLabel,
                  icon: Icons.public,
                  onLike: () => viewModel.setLikeStatus('Nationality', 1),
                  onDislike: () => viewModel.setLikeStatus('Nationality', -1),
                  isLiked: viewModel.getLikeStatus('Nationality') == 1,
                  isDisliked: viewModel.getLikeStatus('Nationality') == -1,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required BuildContext context,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required String title,
    required double confidence,
    required String result,
    required IconData icon,
    required VoidCallback onLike,
    required VoidCallback onDislike,
    required bool isLiked,
    required bool isDisliked,
  }) {
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
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
                    GestureDetector(
                      onTap: onLike,
                      child: Icon(
                        Icons.thumb_up_outlined,
                        size: 16,
                        color:
                            isLiked
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onDislike,
                      child: Icon(
                        Icons.thumb_down_outlined,
                        size: 16,
                        color:
                            isDisliked
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Confidenza: ',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${(confidence * 100).toStringAsFixed(2)}%',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedBreakdown(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    AudioAnalysisDetailViewModel viewModel,
  ) {
    final analysis = viewModel.analysisDetail;

    // prepare label maps
    final ageLabels = {
      'YF': 'Giovane donna',
      'YM': 'Giovane uomo',
      'F': 'Donna',
      'M': 'Uomo',
      'C': 'Bambino/a',
    };
    final natLabels = {
      'IT': 'Italiano',
      'FR': 'Francese',
      'EN': 'Inglese',
      'ES': 'Spagnolo',
      'DE': 'Tedesco',
    };

    return Card(
      elevation: 2,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Breakdown dettagliato',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Età
            /*_buildBreakdownSection(
              title: 'Età',
              data: viewModel.analysisDetail.ageGenderPredictions,
              labels: ageLabels,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            const SizedBox(height: 12),

            // Genere
            _buildBreakdownSection(
              title: 'Genere',
              data: viewModel.analysisDetails.nationalityPredictions,
              labels: natLabels,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),*/
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownSection({
    required String title,
    required Map<String, double> data,
    required Map<String, String> labels,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(color: colorScheme.primary),
        ),
        const SizedBox(height: 8),
        ...data.entries.map((e) {
          final label = labels[e.key] ?? e.key;
          final pct = (e.value * 100).toInt();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(label, style: textTheme.bodyMedium),
                    const Spacer(),
                    Text('$pct%', style: textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: e.value,
                  minHeight: 6,
                  color: colorScheme.primary,
                  backgroundColor: colorScheme.surfaceVariant,
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
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
}
