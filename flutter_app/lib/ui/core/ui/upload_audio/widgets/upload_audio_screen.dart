// lib/ui/core/ui/upload_audio/widgets/upload_audio_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/ui/core/save_audio_dialog.dart';
import 'package:mobile_speech_recognition/ui/core/ui/upload_audio/view_models/upload_audio_view_model.dart';
import 'package:mobile_speech_recognition/ui/core/ui/analysis_detail/widgets/audio_analysis_detail_screen.dart';
import 'package:mobile_speech_recognition/ui/core/ui/analysis_detail/widgets/audio_player_widget.dart';
import 'package:provider/provider.dart';

class UploadAudioScreen extends StatefulWidget {
  const UploadAudioScreen({super.key});

  @override
  State<UploadAudioScreen> createState() => _UploadAudioScreenState();
}

class _UploadAudioScreenState extends State<UploadAudioScreen> {
  late UploadAudioViewModel viewModel;
  bool _shouldClipAudio = false;

  @override
  void initState() {
    super.initState();
    viewModel = UploadAudioViewModel(context);
  }

  @override
  void dispose() {
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
          ;
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
              onPressed: () => _selectFile(model),
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
            onPressed: () => Navigator.pop(context),
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
                    ? () => _showSaveDialog(model)
                    : () => _selectFile(model),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              model.hasSelectedFile ? 'Save & Analyze' : 'Select File',
            ),
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
      // Show duration warning dialog
      await _showDurationWarningDialog(model);
    }
  }

  Future<void> _showDurationWarningDialog(UploadAudioViewModel model) async {
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
              onPressed: () => Navigator.of(dialogContext).pop(true),
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
      setState(() {}); // Refresh UI to show the warning in file info
    }
  }

  Future<void> _showSaveDialog(UploadAudioViewModel model) async {
    final SaveAudioResult? result = await showDialog<SaveAudioResult>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return SaveAudioDialog.forUpload();
      },
    );

    if (result != null) {
      // Set the title and description in the view model
      model.title = result.title;
      model.description = result.description;

      try {
        // Save the uploaded audio
        final analysis = await model.saveAudioAnalysis(
          clipAudio: _shouldClipAudio,
        );

        if (analysis != null) {
          // Close the upload screen
          Navigator.pop(context);

          // Navigate to analysis detail
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      AudioAnalysisDetailScreen(analysisId: analysis.id!),
            ),
          );
        } else {
          // Show error if save failed
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save uploaded audio'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving audio: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
