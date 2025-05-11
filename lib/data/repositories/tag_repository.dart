import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/config/database_config.dart';
import 'package:mobile_speech_recognition/data/services/database_service.dart';
import 'package:mobile_speech_recognition/domain/models/tag/tag.dart';
import 'package:sqflite/sqflite.dart';

class TagRepository extends ChangeNotifier
{
    final DatabaseService _databaseService = DatabaseService();

    Future<void> saveTag(Tag tag) async {
        final db = await _databaseService.database;
        await db.insert(
            'tags',
            tag.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
        );

        notifyListeners();
    }

    Future<List<Tag>> getTagsByAnalysisId(int analysisId) async {
        final db = await _databaseService.database;
        final List<Map<String, dynamic>> maps = await db.query(
            DatabaseConfig.analysisTagTable,
            where: 'ANALYSIS_ID = ?',
            whereArgs: [analysisId],
        );

        return List.generate(maps.length, (i) {
            return Tag.fromMap(maps[i]);
        });
    }
   
    Future<List<Tag>> getAllTags() async {
        final db = await _databaseService.database;
        final List<Map<String, dynamic>> maps = await db.query('tags');

        return List.generate(maps.length, (i) {
            return Tag.fromMap(maps[i]);
        });
    }

    Future<void> deleteTag(int id) async {
        final db = await _databaseService.database;
        await db.delete(
            'tags',
            where: '_id = ?',
            whereArgs: [id],
        );

        notifyListeners();
    }

    Future<void> deleteAllTags() async {
        final db = await _databaseService.database;
        await db.delete('tags');

        notifyListeners();
    }


}