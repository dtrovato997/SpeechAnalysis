// lib/data/repositories/audio_analysis_repository.dart
import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/config/database_config.dart';
import 'package:mobile_speech_recognition/data/repositories/tag_repository.dart';
import 'package:mobile_speech_recognition/data/services/audio_analysis_api_service.dart';
import 'package:mobile_speech_recognition/data/services/database_service.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis/audio_analysis.dart';
import 'package:mobile_speech_recognition/data/services/file_management_service.dart';
import 'package:sqflite/sqflite.dart';

class AudioAnalysisRepository extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final TagRepository _tagRepository = TagRepository();
  final FileManagementService _fileManagementService = FileManagementService();
  final AudioAnalysisApiService _apiService = AudioAnalysisApiService();

  // Constants for send status
  static const int SEND_STATUS_PENDING = 0;
  static const int SEND_STATUS_SENT = 1;
  static const int SEND_STATUS_ERROR = 2;

  /// Creates a new audio analysis and saves it to the database
  /// Also moves the recording file to a permanent location
  /// Then automatically sends it to the server for analysis
  Future<AudioAnalysis> createAnalysis({
    required String title,
    String? description,
    required String recordingPath,
  }) async {
    final db = await _databaseService.database;

    // Create new analysis object with initial values
    final analysis = AudioAnalysis(
      title: title,
      description: description,
      sendStatus: SEND_STATUS_PENDING, // Initial status is pending
      recordingPath: recordingPath,
      creationDate: DateTime.now(),
      // All other fields are null initially
    );

    // Insert into database to get the ID
    final id = await db.insert(
      DatabaseConfig.analysisTable,
      analysis.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Now that we have the ID, store the audio file permanently
    final updatedFilePath = await _fileManagementService.storeAudioFile(
      recordingPath,
      id,
    );

    // Update the analysis with the new ID and file path
    AudioAnalysis updatedAnalysis = analysis.copyWith(
      id: id,
      recordingPath: updatedFilePath,
    );

    // Update the database with the new file path
    await db.update(
      DatabaseConfig.analysisTable,
      {'RECORDING_PATH': updatedFilePath},
      where: '_id = ?',
      whereArgs: [id],
    );

    notifyListeners();

    // Send to server for analysis in the background
    _sendToServerAsync(updatedAnalysis);

    return updatedAnalysis;
  }

  /// Send analysis to server asynchronously and update database with results
  Future<void> _sendToServerAsync(AudioAnalysis analysis) async {
    if (analysis.id == null) {
      print('Cannot send analysis without ID');
      return;
    }

    try {
      print('Sending analysis ${analysis.id} to server...');
      
      // Check server health first
      final isServerHealthy = await _apiService.checkServerHealth();
      if (!isServerHealthy) {
        throw Exception('Server is not available or models are not loaded');
      }

      // Send audio file for complete prediction
      final completePrediction = await _apiService.predictAll(analysis.recordingPath);
      
      if (completePrediction != null) {
        // Convert to AudioAnalysis format with separate age, gender, nationality, and emotion
        final demographicsResult = completePrediction.demographics.toAudioAnalysisFormat();
        final nationalityResult = completePrediction.nationality.toAudioAnalysisFormat();
        final emotionResult = completePrediction.emotion.toAudioAnalysisFormat();
        
        // Extract age and gender separately
        final ageResult = demographicsResult['age'] as double?;
        final genderResult = demographicsResult['gender'] as Map<String, double>?;
        
        // Update the analysis with results
        final updatedAnalysis = analysis.copyWith(
          sendStatus: SEND_STATUS_SENT,
          completionDate: DateTime.now(),
          ageResult: ageResult, 
          genderResult: genderResult,
          nationalityResult: nationalityResult,
          emotionResult: emotionResult,
          errorMessage: null,
        );

        // Update database
        await _updateAnalysisInDatabase(updatedAnalysis);
        
        print('Analysis ${analysis.id} completed successfully');
      } else {
        throw Exception('Server returned null predictions');
      }
    } catch (e) {
      print('Error sending analysis ${analysis.id} to server: $e');
      
      String errorMessage;
      
      if (e is HttpException) {
        errorMessage = e.message;
      } else {
        errorMessage = 'An internal error occurred during analysis processing.';
      }
      
      final errorAnalysis = analysis.copyWith(
        sendStatus: SEND_STATUS_ERROR,
        errorMessage: errorMessage,
      );

      await _updateAnalysisInDatabase(errorAnalysis);
    }

    notifyListeners();
  }

  Future<void> _updateAnalysisInDatabase(AudioAnalysis analysis) async {
    if (analysis.id == null) return;

    final db = await _databaseService.database;
    await db.update(
      DatabaseConfig.analysisTable,
      analysis.toMap(),
      where: '_id = ?',
      whereArgs: [analysis.id],
    );
  }

  Future<void> retryAnalysis(int analysisId) async {
    final analysis = await getAnalysisById(analysisId);
    if (analysis == null) {
      throw Exception('Analysis not found');
    }

    if (analysis.sendStatus != SEND_STATUS_ERROR) {
      throw Exception('Can only retry failed analyses');
    }

    final resetAnalysis = analysis.copyWith(
      sendStatus: SEND_STATUS_PENDING,
      errorMessage: null,
    );

    await _updateAnalysisInDatabase(resetAnalysis);
    notifyListeners();

    await _sendToServerAsync(resetAnalysis);
  }

  Future<void> saveAnalysis(AudioAnalysis analysis) async {
    final db = await _databaseService.database;
    await db.insert(
      DatabaseConfig.analysisTable,
      analysis.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    notifyListeners();
  }

  // Get analysis by ID
  Future<AudioAnalysis?> getAnalysisById(int id) async {
    final db = await _databaseService.database;

    // Query the database for the analysis with the given ID
    final maps = await db.query(
      DatabaseConfig.analysisTable,
      where: '_id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) {
      // Analysis not found
      return null;
    }

    // Return the found analysis
    return AudioAnalysis.fromMap(maps.first);
  }

  Future<List<AudioAnalysis>> getAllAudioAnalyses() async {
    final db = await _databaseService.database;
    List<Map<String, dynamic>> maps = await db.query(
      DatabaseConfig.analysisTable,
    );

    var list = List.generate(maps.length, (i) {
      return AudioAnalysis.fromMap(maps[i]);
    });

    for (var analysis in list) {
      analysis.tags = await _tagRepository.getTagsByAnalysisId(analysis.id!);
    }
    return list;
  }

  // Get recent analyses with optional limit
  Future<List<AudioAnalysis>> getRecentAnalyses({int limit = 5}) async {
    final db = await _databaseService.database;

    // Query recent analyses ordered by creation date (newest first)
    final maps = await db.query(
      DatabaseConfig.analysisTable,
      orderBy: 'CREATION_DATE DESC',
      limit: limit,
    );

    // Create a list of analyses
    final analyses = maps.map((map) => AudioAnalysis.fromMap(map)).toList();

    return analyses;
  }

  /// Get analyses by status
  Future<List<AudioAnalysis>> getAnalysesByStatus(int status) async {
    final db = await _databaseService.database;

    final maps = await db.query(
      DatabaseConfig.analysisTable,
      where: 'SEND_STATUS = ?',
      whereArgs: [status],
      orderBy: 'CREATION_DATE DESC',
    );

    return maps.map((map) => AudioAnalysis.fromMap(map)).toList();
  }

  /// Get pending analyses (not yet sent to server)
  Future<List<AudioAnalysis>> getPendingAnalyses() async {
    return getAnalysesByStatus(SEND_STATUS_PENDING);
  }

  /// Get failed analyses (error occurred)
  Future<List<AudioAnalysis>> getFailedAnalyses() async {
    return getAnalysesByStatus(SEND_STATUS_ERROR);
  }

  /// Get completed analyses (successfully processed)
  Future<List<AudioAnalysis>> getCompletedAnalyses() async {
    return getAnalysesByStatus(SEND_STATUS_SENT);
  }

  Future<void> deleteAudioAnalysis(int id, {bool doNotify = true}) async {
    final db = await _databaseService.database;

    // Delete from database
    await db.delete(
      DatabaseConfig.analysisTable,
      where: '_id = ?',
      whereArgs: [id],
    );

    // Also delete the physical files
    await _fileManagementService.deleteRecording(id);

    if(doNotify) {
      notifyListeners();
    }
  }

  /// Check server connectivity
  Future<bool> isServerAvailable() async {
    return await _apiService.checkServerHealth();
  }

  /// Manually send a specific analysis to server (useful for testing)
  Future<void> sendAnalysisToServer(int analysisId) async {
    final analysis = await getAnalysisById(analysisId);
    if (analysis == null) {
      throw Exception('Analysis not found');
    }

    await _sendToServerAsync(analysis);
  }
}