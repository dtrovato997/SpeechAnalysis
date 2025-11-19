class AudioAnalysis {
  final int? id;
  final String title;
  final String? description;
  final int sendStatus;
  final String? errorMessage;
  final String recordingPath;
  final DateTime creationDate;
  final DateTime? completionDate;
  final double? ageResult; 
  final Map<String,double>? genderResult; 
  final Map<String,double>? nationalityResult; 
  final Map<String,double>? emotionResult; 
  final bool? ageFeedback;
  final bool? genderFeedback;
  final bool? nationalityFeedback;
  final bool? emotionFeedback; 

  AudioAnalysis({
    this.id,
    required this.title,
    this.description,
    required this.sendStatus,
    this.errorMessage,
    required this.recordingPath,
    required this.creationDate,
    this.completionDate,
    this.ageResult,
    this.genderResult,
    this.nationalityResult,
    this.emotionResult,
    this.ageFeedback,
    this.genderFeedback,
    this.nationalityFeedback,
    this.emotionFeedback,
  });

  // Factory method to create Analysis from a Map
  factory AudioAnalysis.fromMap(Map<String, dynamic> map) {
    return AudioAnalysis(
      id: map['_id'] as int?,
      title: map['TITLE'] as String,
      description: map['DESCRIPTION'] as String?,
      sendStatus: map['SEND_STATUS'] as int,
      errorMessage: map['ERROR_MESSAGE'] as String?,
      recordingPath: map['RECORDING_PATH'] as String,
      creationDate: DateTime.parse(map['CREATION_DATE'] as String),
      completionDate: map['COMPLETION_DATE'] != null
          ? DateTime.parse(map['COMPLETION_DATE'] as String)
          : null,
      ageResult: map['AGE_RESULT'] as double?,
      genderResult: _stringToMap(map['GENDER_RESULT'] as String?),
      nationalityResult: _stringToMap(map['NATIONALITY_RESULT'] as String?),
      emotionResult: _stringToMap(map['EMOTION_RESULT'] as String?), 
      ageFeedback: map['AGE_USER_FEEDBACK'] == 1,
      genderFeedback: map['GENDER_USER_FEEDBACK'] == 1,
      nationalityFeedback: map['NATIONALITY_USER_FEEDBACK'] == 1,
      emotionFeedback: map['EMOTION_USER_FEEDBACK'] == 1, 
    );
  }

  // Convert Analysis to a Map for database operations
  Map<String, dynamic> toMap() {
    return {
      if (id != null) '_id': id,
      'TITLE': title,
      'DESCRIPTION': description,
      'SEND_STATUS': sendStatus,
      'ERROR_MESSAGE': errorMessage,
      'RECORDING_PATH': recordingPath,
      'CREATION_DATE': creationDate.toIso8601String(),
      'COMPLETION_DATE': completionDate?.toIso8601String(),
      'AGE_RESULT': ageResult,
      'GENDER_RESULT': _mapToString(genderResult),
      'NATIONALITY_RESULT': _mapToString(nationalityResult),
      'EMOTION_RESULT': _mapToString(emotionResult),
      'AGE_USER_FEEDBACK': ageFeedback != null ? (ageFeedback! ? 1 : 0) : null,
      'GENDER_USER_FEEDBACK': genderFeedback != null ? (genderFeedback! ? 1 : 0) : null,
      'NATIONALITY_USER_FEEDBACK': nationalityFeedback != null ? (nationalityFeedback! ? 1 : 0) : null,
      'EMOTION_USER_FEEDBACK': emotionFeedback != null ? (emotionFeedback! ? 1 : 0) : null, // New emotion feedback
    };
  }

  // Create a copy of this Analysis with given fields replaced with new values
  AudioAnalysis copyWith({
    int? id,
    String? title,
    String? description,
    int? sendStatus,
    String? errorMessage,
    String? recordingPath,
    DateTime? creationDate,
    DateTime? completionDate,
    double? ageResult,
    Map<String,double>? genderResult,
    Map<String,double>? nationalityResult,
    Map<String,double>? emotionResult,
    bool? ageFeedback,
    bool? genderFeedback,
    bool? nationalityFeedback,
    bool? emotionFeedback,
  }) {
    return AudioAnalysis(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      sendStatus: sendStatus ?? this.sendStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      recordingPath: recordingPath ?? this.recordingPath,
      creationDate: creationDate ?? this.creationDate,
      completionDate: completionDate ?? this.completionDate,
      ageResult: ageResult ?? this.ageResult,
      genderResult: genderResult ?? this.genderResult,
      nationalityResult: nationalityResult ?? this.nationalityResult,
      emotionResult: emotionResult ?? this.emotionResult,
      ageFeedback: ageFeedback ?? this.ageFeedback,
      genderFeedback: genderFeedback ?? this.genderFeedback,
      nationalityFeedback: nationalityFeedback ?? this.nationalityFeedback,
      emotionFeedback: emotionFeedback ?? this.emotionFeedback,
    );
  }

  /// Turn a string like "[YF:0.98,OF:0.1,CF:0.1]" into a Map.
  static Map<String, double>? _stringToMap(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.length < 2 ||
        !trimmed.startsWith('[') ||
        !trimmed.endsWith(']')) {
      return null;
    }
    final body = trimmed.substring(1, trimmed.length - 1);
    if (body.isEmpty) return <String, double>{};
    final map = <String, double>{};
    for (final pair in body.split(',')) {
      final parts = pair.split(':');
      if (parts.length != 2) continue;
      final key = parts[0].trim();
      final value = double.tryParse(parts[1].trim());
      if (value != null) {
        map[key] = value;
      }
    }
    return map;
  }

  /// Turn a Map into a string like "[K1:V1,K2:V2]".
  static String? _mapToString(Map<String, double>? map) {
    if (map == null) return null;
    final entries = map.entries
        .map((e) => '${e.key}:${e.value}')
        .join(',');
    return '[$entries]';
  }
}