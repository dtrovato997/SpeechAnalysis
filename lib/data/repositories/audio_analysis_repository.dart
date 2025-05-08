import 'package:mobile_speech_recognition/config/database_config.dart';
import 'package:mobile_speech_recognition/data/repositories/tag_repository.dart';
import 'package:mobile_speech_recognition/data/services/database_service.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis.dart';
import 'package:mobile_speech_recognition/data/services/file_management_service.dart';
import 'package:sqflite/sqflite.dart';

class AudioAnalysisRepository {
  final DatabaseService _databaseService = DatabaseService();
  final TagRepository _tagRepository = TagRepository();
  final FileManagementService _fileManagementService = FileManagementService();

  // Constants for send status
  static const int SEND_STATUS_PENDING = 0;
  static const int SEND_STATUS_SENT = 1;
  static const int SEND_STATUS_ERROR = 2;

  /// Creates a new audio analysis and saves it to the database
  /// Also moves the recording file to a permanent location
  Future<AudioAnalysis> createAnalysis({
    required String title,
    String? description,
    required String recordingPath
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
      id
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
    
    return updatedAnalysis;
  }

  Future<void> saveAnalysis(AudioAnalysis analysis) async {
    final db = await _databaseService.database;
    await db.insert(
      DatabaseConfig.analysisTable,
      analysis.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AudioAnalysis>> getAllAudioAnalyses() async {
    final db = await _databaseService.database;
    List<Map<String, dynamic>> maps = await db.query(DatabaseConfig.analysisTable);

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

  Future<void> deleteAudioAnalysis(int id) async {
    final db = await _databaseService.database;
    
    // Delete from database
    await db.delete(
      DatabaseConfig.analysisTable,
      where: '_id = ?',
      whereArgs: [id],
    );
    
    // Also delete the physical files
    await _fileManagementService.deleteRecording(id);
  }
}