import 'package:mobile_speech_recognition/config/database_config.dart';
import 'package:mobile_speech_recognition/data/repositories/tag_repository.dart';
import 'package:mobile_speech_recognition/data/services/database_service.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis.dart';
import 'package:sqflite/sqflite.dart';


class AudioAnalysisRepository {

  final DatabaseService _databaseService = DatabaseService();
  final TagRepository _tagRepository = TagRepository();

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

  Future<void> deleteAudioAnalysis(int id) async {
    final db = await _databaseService.database;
    await db.delete(
      DatabaseConfig.analysisTable,
      where: '_id = ?',
      whereArgs: [id],
    );
  }
  
  

}