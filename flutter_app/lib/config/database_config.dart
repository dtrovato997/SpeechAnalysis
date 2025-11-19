class DatabaseConfig {
  static const String databaseName = 'SpeechAnalysis.db';
  static const int databaseVersion = 5; // Incrementata la versione

  // Table names
  static const String analysisTable = 'AudioAnalysis';

  // Create table scripts
  static final List<String> createTableScripts = [
    // Analysis table with separate age, gender, nationality, and emotion fields
    '''
    CREATE TABLE $analysisTable (
      _id INTEGER PRIMARY KEY AUTOINCREMENT,
      TITLE TEXT NOT NULL,
      DESCRIPTION TEXT,
      SEND_STATUS INTEGER NOT NULL,
      ERROR_MESSAGE TEXT,
      RECORDING_PATH TEXT NOT NULL,
      CREATION_DATE TEXT NOT NULL,
      COMPLETION_DATE TEXT,
      AGE_RESULT REAL,
      GENDER_RESULT TEXT,
      NATIONALITY_RESULT TEXT,
      EMOTION_RESULT TEXT,
      AGE_USER_FEEDBACK INTEGER,
      GENDER_USER_FEEDBACK INTEGER,
      NATIONALITY_USER_FEEDBACK INTEGER,
      EMOTION_USER_FEEDBACK INTEGER
    )
    '''
  ];

  /// Migration scripts keyed by target version
  static final Map<int, List<String>> migrationScripts = {
    4: [
      // Add emotion columns to existing tables
      'ALTER TABLE $analysisTable ADD COLUMN EMOTION_RESULT TEXT',
      'ALTER TABLE $analysisTable ADD COLUMN EMOTION_USER_FEEDBACK INTEGER',
    ],
    5: [
      // Remove tag-related tables
      'DROP TABLE IF EXISTS $analysisTagTable',
      'DROP TABLE IF EXISTS $tagTable',
    ],
  };
  
  // Nomi delle tabelle rimosse (per riferimento nella migrazione)
  static const String tagTable = 'Tag';
  static const String analysisTagTable = 'AudioAnalysisTag';
}