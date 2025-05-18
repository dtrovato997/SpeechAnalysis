import 'package:mobile_speech_recognition/domain/models/tag/tag.dart';

class AudioAnalysis {
  final int? id;
  final String title;
  final String? description;
  final int sendStatus;
  final String? errorMessage;
  final String recordingPath;
  final DateTime creationDate;
  final DateTime? completionDate;
  final Map<String,double>? ageAndGenderResult;
  final Map<String,double>? nationalityResult;
  final bool? ageFeedback;
  final bool? genderFeedback;
  final bool? nationalityFeedback;
  List<Tag>? tags; // Changed from String? tags to List<Tag>? tags

  AudioAnalysis({
    this.id,
    required this.title,
    this.description,
    this.tags,
    required this.sendStatus,
    this.errorMessage,
    required this.recordingPath,
    required this.creationDate,
    this.completionDate,
    this.ageAndGenderResult,
    this.nationalityResult,
    this.ageFeedback,
    this.genderFeedback,
    this.nationalityFeedback
  });

  // Factory method to create Analysis from a Map
  // Note: This doesn't load tags - they need to be loaded separately
  /// Factory: parse those two columns into Maps
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
      ageAndGenderResult:
          _stringToMap(map['AGE_AND_GENDER_RESULT'] as String?),
      nationalityResult:
          _stringToMap(map['NATIONALITY_RESULT'] as String?),
      ageFeedback: map['AGE_USER_FEEDBACK'] == 1,
      genderFeedback: map['GENDER_USER_FEEDBACK'] == 1,
      nationalityFeedback: map['NATIONALITY_USER_FEEDBACK'] == 1,
      tags: null,
    );
  }

  // Convert Analysis to a Map for database operations
  // Note: This doesn't include tags - they need to be saved separately
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
      'AGE_AND_GENDER_RESULT': _mapToString(ageAndGenderResult),
      'NATIONALITY_RESULT': _mapToString(nationalityResult),
      'AGE_USER_FEEDBACK': ageFeedback != null ? (ageFeedback! ? 1 : 0) : null,
      'GENDER_USER_FEEDBACK':
          genderFeedback != null ? (genderFeedback! ? 1 : 0) : null,
      'NATIONALITY_USER_FEEDBACK':
          nationalityFeedback != null ? (nationalityFeedback! ? 1 : 0) : null,
    };
  }

  // Create a copy of this Analysis with given fields replaced with new values
  AudioAnalysis copyWith({
    int? id,
    String? title,
    String? description,
    List<Tag>? tags,
    int? sendStatus,
    String? errorMessage,
    String? recordingPath,
    DateTime? creationDate,
    DateTime? completionDate,
    Map<String,double>? ageAndGenderResult,
    Map<String,double>? nationalityResult,
    bool? ageFeedback,
    bool? genderFeedback,
    bool? nationalityFeedback
  }) {
    return AudioAnalysis(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      sendStatus: sendStatus ?? this.sendStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      recordingPath: recordingPath ?? this.recordingPath,
      creationDate: creationDate ?? this.creationDate,
      completionDate: completionDate ?? this.completionDate,
      ageAndGenderResult: ageAndGenderResult ?? this.ageAndGenderResult,
      nationalityResult: nationalityResult ?? this.nationalityResult,
      ageFeedback: ageFeedback ?? this.ageFeedback,
      genderFeedback: genderFeedback ?? this.genderFeedback,
      nationalityFeedback: nationalityFeedback ?? this.nationalityFeedback
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