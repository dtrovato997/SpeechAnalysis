// lib/ui/core/ui/analysis_detail/widgets/audio_analysis_detail_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/ui/core/ui/analysis_detail/view_models/audio_analysis_detail_view_model.dart';
import 'package:mobile_speech_recognition/ui/core/ui/analysis_detail/widgets/audio_player_widget.dart';
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
    );
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
    if (viewModel.analysisDetail == null) {
      return const SizedBox.shrink();
    }

    return AudioPlayerWidget(
      audioPath: viewModel.analysisDetail!.recordingPath,
      colorScheme: colorScheme,
      textTheme: textTheme,
    );
  }

Widget _buildResultsCardsFixed(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    AudioAnalysisDetailViewModel viewModel,
  ) {
    final analysis = viewModel.analysisDetail;

    // Check for error status first
    if (analysis?.sendStatus == 2) {
      return _buildErrorCard(context, colorScheme, textTheme, analysis!);
    }

    if (analysis?.sendStatus != 1) {
      // Show loading or pending state
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
                'Analysis Result',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    analysis?.sendStatus == 0 
                        ? 'Analysis in progress...' 
                        : 'Processing...',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Check if we have results
    if (analysis?.ageResult == null && 
        (analysis?.genderResult == null || analysis!.genderResult!.isEmpty) &&
        (analysis?.nationalityResult == null || analysis!.nationalityResult!.isEmpty)) {
      return const SizedBox.shrink();
    }

    // Get age result
    final ageResult = analysis?.ageResult;
    final ageText = ageResult != null ? '${ageResult.round()} years' : 'Unknown';

    // Get the most likely gender
    String genderText = 'Unknown';
    String genderKey = 'Unknown';
    if (analysis?.genderResult != null && analysis!.genderResult!.isNotEmpty) {
      final genderEntry = analysis.genderResult!.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      genderKey = genderEntry.key;
      
      // Map gender codes to Italian labels
      if (genderKey == 'M') {
        genderText = 'Uomo';
      } else if (genderKey == 'F') {
        genderText = 'Donna';
      }
    }

    // Get the most likely nationality
    String nationalityText = 'Sconosciuto';
    if (analysis?.nationalityResult != null && analysis!.nationalityResult!.isNotEmpty) {
      final nationalityEntry = analysis.nationalityResult!.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      
      // Map nationality codes to Italian labels
      final nationalityKey = nationalityEntry.key;
      if (nationalityKey == 'IT') {
        nationalityText = 'Italiano';
      } else if (nationalityKey == 'FR') {
        nationalityText = 'Francese';
      } else if (nationalityKey == 'EN') {
        nationalityText = 'Inglese';
      } else if (nationalityKey == 'ES') {
        nationalityText = 'Spagnolo';
      } else if (nationalityKey == 'DE') {
        nationalityText = 'Tedesco';
      }
    }

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
                // Age Card
                if (ageResult != null)
                  _buildResultCard(
                    context: context,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    title: 'Età',
                    confidence: 1.0, // Age is regression, so confidence is not applicable
                    result: ageText,
                    icon: Icons.cake,
                    onLike: () => viewModel.setLikeStatus('Age', 1),
                    onDislike: () => viewModel.setLikeStatus('Age', -1),
                    isLiked: viewModel.getLikeStatus('Age') == 1,
                    isDisliked: viewModel.getLikeStatus('Age') == -1,
                    showConfidence: false, // Don't show confidence for age
                  ),
                
                if (ageResult != null && analysis!.genderResult != null && analysis.genderResult!.isNotEmpty)
                  const SizedBox(height: 12),
                
                // Gender Card
                if (analysis!.genderResult != null && analysis.genderResult!.isNotEmpty)
                  _buildResultCard(
                    context: context,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    title: 'Genere',
                    confidence: analysis.genderResult!.entries.reduce(
                      (a, b) => a.value > b.value ? a : b,
                    ).value / 100.0, // Convert percentage to decimal
                    result: genderText,
                    icon: _getGenderIcon(genderKey),
                    onLike: () => viewModel.setLikeStatus('Gender', 1),
                    onDislike: () => viewModel.setLikeStatus('Gender', -1),
                    isLiked: viewModel.getLikeStatus('Gender') == 1,
                    isDisliked: viewModel.getLikeStatus('Gender') == -1,
                  ),
                
                if (analysis.nationalityResult != null && analysis.nationalityResult!.isNotEmpty)
                  const SizedBox(height: 12),
                
                // Nationality Card
                if (analysis.nationalityResult != null && analysis.nationalityResult!.isNotEmpty)
                  _buildResultCard(
                    context: context,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    title: 'Nazionalità',
                    confidence: analysis.nationalityResult!.entries.reduce(
                      (a, b) => a.value > b.value ? a : b,
                    ).value / 100.0, // Convert percentage to decimal
                    result: nationalityText,
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

  /// Build error card for failed analysis
  Widget _buildErrorCard(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    analysis,
  ) {
    return Card(
      elevation: 2,
      color: colorScheme.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with error icon
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: colorScheme.error,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Analysis Failed',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Error message section
            if (analysis.errorMessage != null && analysis.errorMessage!.isNotEmpty) ...[
              Text(
                'Error Message:',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.error.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  analysis.errorMessage!,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontFamily: 'monospace', // Use monospace for error messages
                  ),
                ),
              ),
            ] else ...[
              // Generic error message if no specific error is provided
              Text(
                'Error Message:',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.error.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  'An unexpected error occurred during analysis processing.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Consumer<AudioAnalysisDetailViewModel>(
                  builder: (context, vm, child) {
                    return TextButton.icon(
                      onPressed: vm.isRetrying ? null : () async {
                        await vm.retryAnalysis();
                        
                        // Show feedback to user
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Analysis retry initiated'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: vm.isRetrying 
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          )
                        : Icon(
                            Icons.refresh,
                            size: 18,
                            color: vm.isRetrying 
                                ? colorScheme.onSurface.withOpacity(0.38)
                                : colorScheme.primary,
                          ),
                      label: Text(
                        vm.isRetrying ? 'Retrying...' : 'Retry Analysis',
                        style: TextStyle(
                          color: vm.isRetrying 
                              ? colorScheme.onSurface.withOpacity(0.38)
                              : colorScheme.primary,
                        ),
                      ),
                    );
                  },
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
    bool showConfidence = true, // New parameter to control confidence display
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
            if (showConfidence) ...[
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
          ],
        ),
      ),
    );
  }

  IconData _getGenderIcon(String key) {
    if (key == 'F') {
      return Icons.female;
    } else if (key == 'M') {
      return Icons.male;
    }
    return Icons.person;
  }
}