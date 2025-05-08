// file_management_service_impl.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis.dart';

class FileManagementService {
  static final FileManagementService _instance = FileManagementService._internal();

  factory FileManagementService() => _instance;

  FileManagementService._internal();

  /// Stores an audio file for an existing AudioAnalysis in a persistent location
  /// Returns the path where the file was stored
  Future<String> storeAudioFile(String sourceFilePath, int analysisId) async {
    try {
      // Create directory if it doesn't exist
      final directory = await _getRecordingsDirectory();
      final recordingDir = Directory('${directory.path}/recording_$analysisId');
      
      if (!await recordingDir.exists()) {
        await recordingDir.create(recursive: true);
      }

      // Get just the extension from the original filename
      final sourceFile = File(sourceFilePath);
      final originalFilename = sourceFile.path.split('/').last;
      final fileExtension = originalFilename.contains('.') 
          ? originalFilename.split('.').last 
          : '';
      
      // Define target file path with standard name but original extension
      final targetFilePath = fileExtension.isNotEmpty 
          ? '${recordingDir.path}/recording.$fileExtension' 
          : '${recordingDir.path}/recording';
      
      // Copy the file
      await sourceFile.copy(targetFilePath);
      
      return targetFilePath;
    } catch (e) {
      print('Error storing audio file: $e');
      // Return the original path if an error occurs
      return sourceFilePath;
    }
  }

  /// Get the base directory for all recordings
  Future<Directory> _getRecordingsDirectory() async {
    // Use external storage if available, otherwise use app documents directory
    try {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final recordingsDir = Directory('${directory.path}/audio_analysis');
        if (!await recordingsDir.exists()) {
          await recordingsDir.create(recursive: true);
        }
        return recordingsDir;
      } else {
        // Fallback to documents directory
        final directory = await getApplicationDocumentsDirectory();
        final recordingsDir = Directory('${directory.path}/audio_analysis');
        if (!await recordingsDir.exists()) {
          await recordingsDir.create(recursive: true);
        }
        return recordingsDir;
      }
    } catch (e) {
      // Fallback to documents directory if external storage is not available
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/audio_analysis');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }
      return recordingsDir;
    }
  }

  /// Delete a recording directory and all its contents
  Future<bool> deleteRecording(int analysisId) async {
    try {
      final directory = await _getRecordingsDirectory();
      final recordingDir = Directory('${directory.path}/recording_$analysisId');
      
      if (await recordingDir.exists()) {
        await recordingDir.delete(recursive: true);
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting recording: $e');
      return false;
    }
  }
}