// lib/ui/core/ui/analysis_detail/widgets/audio_analysis_detail_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/ui/core/ui/analysis_detail/view_models/audio_analysis_detail_view_model.dart';
import 'package:mobile_speech_recognition/ui/core/ui/analysis_detail/widgets/audio_player_widget.dart';
import 'package:mobile_speech_recognition/utils/analysis_format_utils.dart';
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
                scrolledUnderElevation: 0.0,
                backgroundColor: colorScheme.surfaceBright,
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
              scrolledUnderElevation: 0.0,
              backgroundColor: colorScheme.surfaceBright,
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
              actions: [
                // Delete button in app bar
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: colorScheme.error,
                  ),
                  onPressed: () => _showDeleteConfirmationDialog(context, viewModel),
                  tooltip: 'Delete Analysis',
                ),
              ],
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

  /// Show delete confirmation dialog
  Future<void> _showDeleteConfirmationDialog(
    BuildContext context, 
    AudioAnalysisDetailViewModel viewModel
  ) async {
    final analysis = viewModel.analysisDetail;
    if (analysis == null) return;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must tap button to dismiss
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.error,
            size: 32,
          ),
          title: Text(
            'Delete Analysis',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this analysis?',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Title: ${analysis.title}',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (analysis.description != null && analysis.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Description: ${analysis.description}',
                        style: textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Created: ${AnalysisFormatUtils.formatDate(analysis.creationDate)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    // If user confirmed deletion
    if (shouldDelete == true) {
      await _performDelete(context, viewModel);
    }
  }

  /// Perform the actual deletion
  Future<void> _performDelete(
    BuildContext context, 
    AudioAnalysisDetailViewModel viewModel
  ) async {
    final analysis = viewModel.analysisDetail;
    if (analysis?.id == null) return;

    final colorScheme = Theme.of(context).colorScheme;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: colorScheme.primary),
                const SizedBox(height: 16),
                const Text('Deleting analysis...'),
              ],
            ),
          );
        },
      );

      // Delete the analysis
      await viewModel.deleteAnalysis();

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      // Navigate back first, then show success message
      if (context.mounted) {
        // Navigate back to previous screen
        Navigator.of(context).pop();
        
        // Show success message on the previous screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis "${analysis!.title}" deleted successfully'),
            backgroundColor: colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting analysis: ${e.toString()}'),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OK',
              textColor: colorScheme.onError,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
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
        (analysis?.nationalityResult == null || analysis!.nationalityResult!.isEmpty) &&
        (analysis?.emotionResult == null || analysis!.emotionResult!.isEmpty)) {
      return const SizedBox.shrink();
    }

    // Use AnalysisFormatUtils for consistent parsing
    final ageText = AnalysisFormatUtils.parseAgeResult(analysis?.ageResult);
    final genderText = AnalysisFormatUtils.parseGenderResult(analysis?.genderResult);
    final nationalityText = AnalysisFormatUtils.parseNationalityResult(analysis?.nationalityResult);
    final emotionText = AnalysisFormatUtils.parseEmotionResult(analysis?.emotionResult);

    // Get confidence values for display
    double? genderConfidence;
    double? nationalityConfidence;
    double? emotionConfidence;

    if (analysis?.genderResult != null && analysis!.genderResult!.isNotEmpty) {
      final maxGenderEntry = analysis.genderResult!.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      genderConfidence = maxGenderEntry.value / 100.0; // Convert percentage to decimal
    }

    if (analysis?.nationalityResult != null && analysis!.nationalityResult!.isNotEmpty) {
      final maxNationalityEntry = analysis.nationalityResult!.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      nationalityConfidence = maxNationalityEntry.value / 100.0; // Convert percentage to decimal
    }

    if (analysis?.emotionResult != null && analysis!.emotionResult!.isNotEmpty) {
      final maxEmotionEntry = analysis.emotionResult!.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      emotionConfidence = maxEmotionEntry.value;
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
                if (analysis?.ageResult != null)
                  _buildResultCard(
                    context: context,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    title: 'Età',
                    confidence: 1.0, // Age is regression, so confidence is not applicable
                    result: ageText,
                    icon: Icons.cake,
                    showConfidence: false, // Don't show confidence for age
                  ),

                if (analysis?.ageResult != null && genderText != '--')
                  const SizedBox(height: 12),

                // Gender Card
                if (genderText != '--')
                  _buildResultCard(
                    context: context,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    title: 'Genere',
                    confidence: genderConfidence ?? 0.0,
                    result: genderText,
                    icon: AnalysisFormatUtils.getGenderIcon(genderText),
                  ),

                if (nationalityText != '--')
                  const SizedBox(height: 12),

                // Nationality Card
                if (nationalityText != '--')
                  _buildResultCard(
                    context: context,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    title: 'Nazionalità',
                    confidence: nationalityConfidence ?? 0.0,
                    result: nationalityText,
                    icon: AnalysisFormatUtils.getNationalityIcon(''),
                  ),

                if (emotionText != '--')
                  const SizedBox(height: 12),

                // Emotion Card
                if (emotionText != '--')
                  _buildResultCard(
                    context: context,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    title: 'Emozione',
                    confidence: emotionConfidence ?? 0.0,
                    result: emotionText,
                    icon: AnalysisFormatUtils.getEmotionIcon(emotionText),
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
                Icon(Icons.error_outline, color: colorScheme.error, size: 24),
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
            if (analysis.errorMessage != null &&
                analysis.errorMessage!.isNotEmpty) ...[
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
                      onPressed:
                          vm.isRetrying
                              ? null
                              : () async {
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
                      icon:
                          vm.isRetrying
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
                                color:
                                    vm.isRetrying
                                        ? colorScheme.onSurface.withOpacity(
                                          0.38,
                                        )
                                        : colorScheme.primary,
                              ),
                      label: Text(
                        vm.isRetrying ? 'Retrying...' : 'Retry Analysis',
                        style: TextStyle(
                          color:
                              vm.isRetrying
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
                )
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
                    'Confidence: ',
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
}