import 'package:mobile_speech_recognition/domain/models/tag.dart';

class AudioAnalysis {
  final int? id;
  final String title;
  final String? description;
  final int sendStatus;
  final String? errorMessage;
  final String recordingPath;
  final DateTime creationDate;
  final DateTime? completionDate;
  final String? ageResult;
  final String? genderResult;
  final String? nationalityResult;
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
    this.ageResult,
    this.genderResult,
    this.nationalityResult,
    this.ageFeedback,
    this.genderFeedback,
    this.nationalityFeedback
  });

  // Factory method to create Analysis from a Map
  // Note: This doesn't load tags - they need to be loaded separately
  factory AudioAnalysis.fromMap(Map<String, dynamic> map) {
    return AudioAnalysis(
      id: map['_id'],
      title: map['TITLE'],
      description: map['DESCRIPTION'],
      sendStatus: map['SEND_STATUS'],
      errorMessage: map['ERROR_MESSAGE'],
      recordingPath: map['RECORDING_PATH'],
      creationDate: DateTime.parse(map['CREATION_DATE']),
      completionDate: map['COMPLETION_DATE'] != null 
          ? DateTime.parse(map['COMPLETION_DATE']) 
          : null,
      ageResult: map['AGE_RESULT'],
      genderResult: map['GENDER_RESULT'],
      nationalityResult: map['NATIONALITY_RESULT'],
      ageFeedback: map['AGE_USER_FEEDBACK'] == 1,
      genderFeedback: map['GENDER_USER_FEEDBACK'] == 1,
      nationalityFeedback: map['NATIONALITY_USER_FEEDBACK'] == 1,
      // Tags are loaded separately, so set to null here
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
      'AGE_RESULT': ageResult,
      'GENDER_RESULT': genderResult,
      'NATIONALITY_RESULT': nationalityResult,
      'AGE_USER_FEEDBACK': ageFeedback != null ? (ageFeedback! ? 1 : 0) : null,
      'GENDER_USER_FEEDBACK': genderFeedback != null ? (genderFeedback! ? 1 : 0) : null,
      'NATIONALITY_USER_FEEDBACK': nationalityFeedback != null ? (nationalityFeedback! ? 1 : 0) : null
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
    String? ageResult,
    String? genderResult,
    String? nationalityResult,
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
      ageResult: ageResult ?? this.ageResult,
      genderResult: genderResult ?? this.genderResult,
      nationalityResult: nationalityResult ?? this.nationalityResult,
      ageFeedback: ageFeedback ?? this.ageFeedback,
      genderFeedback: genderFeedback ?? this.genderFeedback,
      nationalityFeedback: nationalityFeedback ?? this.nationalityFeedback
    );
  }
}