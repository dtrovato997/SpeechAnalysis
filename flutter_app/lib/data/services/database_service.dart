import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../../config/database_config.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), DatabaseConfig.databaseName);
    return await openDatabase(
      path,
      version: DatabaseConfig.databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Create tables based on DatabaseConfig
    for (var tableScript in DatabaseConfig.createTableScripts) {
      await db.execute(tableScript);
    }
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Handle migrations logic
    if (oldVersion < newVersion) {
      for (var i = oldVersion + 1; i <= newVersion; i++) {
        var migrationScripts = DatabaseConfig.migrationScripts[i];
        if (migrationScripts != null) {
          for (var script in migrationScripts) {
            await db.execute(script);
          }
        }
      }
    }
  }
}