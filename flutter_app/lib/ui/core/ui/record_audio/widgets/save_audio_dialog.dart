import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/ui/core/ui/analysis_detail/widgets/audio_analysis_detail_screen.dart';
import 'package:mobile_speech_recognition/ui/core/ui/record_audio/view_models/audio_recording_view_model.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class SaveAudioDialog extends StatefulWidget {
  const SaveAudioDialog({Key? key}) : super(key: key);

  @override
  State<SaveAudioDialog> createState() => _SaveAudioDialogState();
}

class _SaveAudioDialogState extends State<SaveAudioDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<String> _tags = [];
  bool _isLoading = true;
  bool _isTitleEmpty = false; // Changed to false since we'll set a default value

  @override
  void initState() {
    super.initState();
    _initializeDialog();
  }

  Future<void> _initializeDialog() async {
    final viewModel = Provider.of<AudioRecordingViewModel>(
      context,
      listen: false,
    );

    // Set default title with localized date and time format
    final now = DateTime.now();
    
    // Use intl package to format the date and time according to the locale
    // This will automatically use the device's locale for formatting
    final dateFormatter = DateFormat('dd_MM_yyyy');
    final formattedDate = dateFormatter.format(now);

        // Listen for changes to update the title validation state
    _titleController.addListener(() {
      setState(() {
        viewModel.Title = _titleController.text;
        _isTitleEmpty = _titleController.text.trim().isEmpty;
      });
    });

    _descriptionController.addListener((){
      viewModel.Description = _descriptionController.text;
    });

    
    // Set the default title in the format: Recording_DD_MM_YYYY_HH_MM_SS
    _titleController.text = 'Recording_${formattedDate}';
    viewModel.Title = _titleController.text;

  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioRecordingViewModel>(
      builder: (context, model, child) {
        final colorScheme = Theme.of(context).colorScheme;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Save Recording',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),

                // Title TextField with validation
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      maxLines: 2,
                      minLines: 1,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _isTitleEmpty 
                                ? colorScheme.error 
                                : colorScheme.outline,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _isTitleEmpty 
                                ? colorScheme.error 
                                : colorScheme.outline,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _isTitleEmpty 
                                ? colorScheme.error 
                                : colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: colorScheme.surface,
                      ),
                    ),
                    if (_isTitleEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 8),
                        child: Text(
                          '*Required',
                          style: TextStyle(
                            color: colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description TextField
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                  ),
                  maxLines: 3,

                ),

                // Tag Dropdown
                const SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        model.Title = '';
                        model.Description = null;
                        Navigator.pop(context); // Cancel
                      },
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        // Use disabledBackgroundColor and disabledForegroundColor for disabled state
                        disabledBackgroundColor: colorScheme.surfaceVariant,
                        disabledForegroundColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      onPressed: _isTitleEmpty
                          ? null // Disable the button when title is empty
                          : () async {
                              // Call the save method on the ViewModel
                              var result = await model.saveRecording();

                              // Close dialog and potentially the entire flow
                              Navigator.pop(context);
                              Navigator.pop(context);

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AudioAnalysisDetailScreen(
                                  analysisId: result?.id ?? -1,
                                  ),
                                ),
                              );
                            },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}