// lib/ui/core/ui/upload_audio/widgets/upload_audio_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/ui/core/save_audio_dialog.dart';
import 'package:mobile_speech_recognition/ui/core/ui/upload_audio/view_models/upload_audio_view_model.dart';
import 'package:mobile_speech_recognition/ui/core/ui/analysis_detail/widgets/audio_analysis_detail_screen.dart';
import 'package:mobile_speech_recognition/ui/core/ui/analysis_detail/widgets/audio_player_widget.dart';
import 'package:mobile_speech_recognition/services/logger_service.dart';
import 'package:provider/provider.dart';

class UploadAudioScreen extends StatefulWidget {
  const UploadAudioScreen({super.key});

  @override
  State<UploadAudioScreen> createState() => _UploadAudioScreenState();
}

class _UploadAudioScreenState extends State<UploadAudioScreen> {
  final _logger = LoggerService();
  late UploadAudioViewModel viewModel;
  bool _shouldClipAudio = false;

  @override
  void initState() {
    super.initState();
    _logger.info('UploadAudioScreen initialized');
    viewModel = UploadAudioViewModel(context);
  }

  @override
  void dispose() {
    _logger.debug('UploadAudioScreen disposing');
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: viewModel,
      child: Consumer<UploadAudioViewModel>(
        builder: (context, model, child) {
          final colorScheme = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
                  child: Column(
                    children: [
                      Text(
                        'Upload Audio',
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select an audio file to analyze',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // File selection
                      if (!model.hasSelectedFile)
                        _buildFileSelectionArea(model, colorScheme, textTheme),

                      // Audio preview
                      if (model.hasSelectedFile) ...[
                        _buildAudioPreviewSection(
                          model,
                          colorScheme,
                          textTheme,
                        ),
                        const SizedBox(height: 16),
                        _buildFileInfoCard(model, colorScheme, textTheme),
                      ],
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                  child: _buildActionButtons(model, colorScheme),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFileSelectionArea(
    UploadAudioViewModel model,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.3),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          // Upload icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.upload_file,
              size: 40,
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 16),

          // Status text
          if (model.isPickingFile)
            Text(
              'Selecting file...',
              style: textTheme.bodyLarge?.copyWith(color: colorScheme.primary),
              textAlign: TextAlign.center,
            )
          else if (model.isCheckingDuration)
            Text(
              'Checking audio duration...',
              style: textTheme.bodyLarge?.copyWith(color: colorScheme.primary),
              textAlign: TextAlign.center,
            )
          else
            Column(
              children: [
                Text(
                  'Tap to select audio file',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Supported formats: MP3, WAV, M4A',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),

          // Error message
          if (model.hasError) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 20, color: colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      model.error!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Select file button
          if (!model.isPickingFile && !model.isCheckingDuration) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _logger.debug('Choose File button pressed');
                _selectFile(model);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose File'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioPreviewSection(
    UploadAudioViewModel model,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    if (model.selectedFilePath == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Audio Preview',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),

        // Audio player widget
        AudioPlayerWidget(
          audioPath: model.selectedFilePath!,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
      ],
    );
  }

  Widget _buildFileInfoCard(
    UploadAudioViewModel model,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      elevation: 1,
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File info title
            Text(
              'File Information',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            // File name
            Row(
              children: [
                Icon(Icons.audio_file, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    model.selectedFilePath?.split('/').last ?? 'Unknown file',
                    style: textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Duration
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Duration: ${model.formatDuration(model.audioDuration)}',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),

            // Duration warning if applicable
            if (model.audioDuration != null &&
                model.audioDuration!.inMinutes >= 2) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _shouldClipAudio
                            ? 'Audio will be clipped to 2 minutes for analysis'
                            : 'Audio is longer than 2 minutes',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    UploadAudioViewModel model,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              _logger.debug('Cancel button pressed');
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: colorScheme.outline),
            ),
            child: const Text('Cancel'),
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: ElevatedButton(
            onPressed:
                model.hasSelectedFile
                    ? () {
                      _logger.info('Save & Analyze button pressed');
                      _showSaveDialog(model);
                    }
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Save & Analyze'),
          ),
        ),
      ],
    );
  }

  Future<void> _selectFile(UploadAudioViewModel model) async {
    final success = await model.pickAudioFile();

    if (success &&
        model.audioDuration != null &&
        model.audioDuration!.inMinutes >= 2) {
      _logger.warning('Selected audio exceeds 2 minutes, showing duration warning');
      // Show duration warning dialog
      await _showDurationWarningDialog(model);
    }
  }

  Future<void> _showDurationWarningDialog(UploadAudioViewModel model) async {
    _logger.info('Showing duration warning dialog - Duration: ${model.formatDuration(model.audioDuration)}');
    
    final bool? shouldContinue = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final textTheme = Theme.of(dialogContext).textTheme;

        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.primary,
            size: 32,
          ),
          title: Text(
            'Audio Duration Warning',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The selected audio file is longer than 2 minutes.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current duration: ${model.formatDuration(model.audioDuration)}',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Maximum allowed: 2:00',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The audio will be automatically clipped to the first 2 minutes for analysis.',
                style: textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                _logger.info('User accepted audio clipping');
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (shouldContinue == true) {
      _shouldClipAudio = true;
      _logger.debug('Audio clipping enabled, refreshing UI');
      setState(() {}); // Refresh UI to show the warning 
    }
  }

  Future<void> _showSaveDialog(UploadAudioViewModel model) async {
    _logger.info('Showing save dialog for uploaded audio');
    
    final SaveAudioResult? result = await showDialog<SaveAudioResult>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return SaveAudioDialog.forUpload(
          initialDescription: model.selectedFilePath?.split('/').last ?? ''
        );
      },
    );

    if (result != null) {
      _logger.info('Save dialog completed - Title: "${result.title}", Has description: ${result.description != null && result.description!.isNotEmpty}');
      
      model.title = result.title;
      model.description = result.description;

      try {
        _logger.info('Saving uploaded audio analysis');
        final analysis = await model.saveAudioAnalysis(
          clipAudio: _shouldClipAudio,
        );

        if (analysis != null) {
          _logger.info('Uploaded audio saved successfully - ID: ${analysis.id}');
          
          // Close the upload screen
          Navigator.pop(context);

          // Navigate to analysis detail
          _logger.debug('Navigating to analysis detail screen');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      AudioAnalysisDetailScreen(analysisId: analysis.id!),
            ),
          );
        } else {
          _logger.error('Failed to save uploaded audio: saveAudioAnalysis returned null');
          // Show error if save failed
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save uploaded audio'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e, stackTrace) {
        _logger.error('Error saving uploaded audio', e, stackTrace);
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving audio: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      _logger.debug('Save dialog cancelled by user');
    }
  }
}