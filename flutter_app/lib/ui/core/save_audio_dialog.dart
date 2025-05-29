// lib/ui/core/widgets/save_audio_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Data class to hold the result from SaveAudioDialog
class SaveAudioResult {
  final String title;
  final String? description;

  const SaveAudioResult({
    required this.title,
    this.description,
  });
}

/// Generic dialog for getting title and description for audio files
/// Can be used for both recording and upload scenarios
class SaveAudioDialog extends StatefulWidget {
  /// The title for the dialog (e.g., "Save Recording", "Save Upload")
  final String dialogTitle;
  
  /// The default prefix for auto-generated titles (e.g., "Recording", "Upload")
  final String titlePrefix;
  
  /// Optional initial title value
  final String? initialTitle;
  
  /// Optional initial description value
  final String? initialDescription;

  const SaveAudioDialog({
    Key? key,
    required this.dialogTitle,
    required this.titlePrefix,
    this.initialTitle,
    this.initialDescription,
  }) : super(key: key);

  static SaveAudioDialog forRecording({
    String? initialTitle,
    String? initialDescription,
  }) {
    return SaveAudioDialog(
      dialogTitle: 'Save Recording',
      titlePrefix: 'Recording',
      initialTitle: initialTitle,
      initialDescription: initialDescription,
    );
  }

  static SaveAudioDialog forUpload({
    String? initialTitle,
    String? initialDescription,
  }) {
    return SaveAudioDialog(
      dialogTitle: 'Save Uploaded Audio',
      titlePrefix: 'Upload',
      initialTitle: initialTitle,
      initialDescription: initialDescription,
    );
  }

  @override
  State<SaveAudioDialog> createState() => _SaveAudioDialogState();
}

class _SaveAudioDialogState extends State<SaveAudioDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isTitleEmpty = false;

  @override
  void initState() {
    super.initState();
    _initializeDialog();
  }

  void _initializeDialog() {
    // Set initial values
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    } else {
      // Generate default title with date
      final now = DateTime.now();
      final dateFormatter = DateFormat('dd_MM_yyyy_HH:mm');
      final formattedDate = dateFormatter.format(now);
      _titleController.text = '${widget.titlePrefix}_$formattedDate';
    }

    if (widget.initialDescription != null) {
      _descriptionController.text = widget.initialDescription!;
    }

    // Listen for title changes to update validation
    _titleController.addListener(() {
      setState(() {
        _isTitleEmpty = _titleController.text.trim().isEmpty;
      });
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
            // Dialog title
            Text(
              widget.dialogTitle,
              style: textTheme.headlineSmall?.copyWith(
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

            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
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
                    disabledBackgroundColor: colorScheme.surfaceVariant,
                    disabledForegroundColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  onPressed: _isTitleEmpty ? null : _handleSave,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleSave() {
    if (_isTitleEmpty) return;

    final result = SaveAudioResult(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim(),
    );

    Navigator.of(context).pop(result);
  }
}